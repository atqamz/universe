#!/usr/bin/env bash
# Fetch Claude API usage data with caching and rate-limit handling.
# Sourced by statusline-command.sh.

CACHE_DIR="${HOME}/.cache/claude/statusline"
CACHE_FILE="${CACHE_DIR}/usage.json"
LOCK_FILE="${CACHE_DIR}/usage.lock"
CACHE_MAX_AGE=600
LOCK_MAX_AGE=30
DEFAULT_RATE_LIMIT_BACKOFF=600
BACKOFF_FILE="${CACHE_DIR}/usage.backoff"
TOKEN_CACHE_FILE="${CACHE_DIR}/token.cache"
TOKEN_CACHE_MAX_AGE=3600

USAGE_API_HOST="api.anthropic.com"
USAGE_API_PATH="/api/oauth/usage"
USAGE_API_TIMEOUT=5

ensure_cache_dir() {
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
}

now() { date +%s; }

file_mtime() {
    stat -c %Y "$1" 2>/dev/null || echo 0
}

get_usage_token() {
    local now_ts
    now_ts=$(now)

    if [[ -f "$TOKEN_CACHE_FILE" ]]; then
        local cache_age=$(( now_ts - $(file_mtime "$TOKEN_CACHE_FILE") ))
        if [[ $cache_age -lt $TOKEN_CACHE_MAX_AGE ]]; then
            cat "$TOKEN_CACHE_FILE" 2>/dev/null && return 0
        fi
    fi

    local token=""
    local cred_file="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json"
    [[ -f "$cred_file" ]] || return 1
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null)

    [[ -n "$token" && "$token" != "null" ]] || return 1

    ensure_cache_dir
    echo "$token" > "$TOKEN_CACHE_FILE" 2>/dev/null
    echo "$token"
}

read_active_lock() {
    local now_ts
    now_ts=$(now)
    [[ -f "$LOCK_FILE" ]] || return 1

    local lock_data
    lock_data=$(cat "$LOCK_FILE" 2>/dev/null)
    if [[ -n "$lock_data" ]]; then
        local blocked_until error
        blocked_until=$(echo "$lock_data" | jq -r '.blockedUntil // empty' 2>/dev/null)
        error=$(echo "$lock_data" | jq -r '.error // "timeout"' 2>/dev/null)
        if [[ -n "$blocked_until" && "$blocked_until" =~ ^[0-9]+$ ]]; then
            if [[ $blocked_until -gt $now_ts ]]; then
                echo "$error:$blocked_until"
                return 0
            fi
            return 1
        fi
    fi

    local lock_mtime
    lock_mtime=$(file_mtime "$LOCK_FILE")
    local blocked_until=$(( lock_mtime + LOCK_MAX_AGE ))
    if [[ $blocked_until -gt $now_ts ]]; then
        echo "timeout:$blocked_until"
        return 0
    fi
    return 1
}

write_lock() {
    local blocked_until="$1"
    local error="${2:-timeout}"
    ensure_cache_dir
    local jitter=$(( RANDOM % 30 ))
    echo "{\"blockedUntil\":$(( blocked_until + jitter )),\"error\":\"$error\"}" > "$LOCK_FILE" 2>/dev/null
}

read_backoff_count() {
    [[ -f "$BACKOFF_FILE" ]] || { echo 0; return; }
    local n
    n=$(cat "$BACKOFF_FILE" 2>/dev/null)
    [[ "$n" =~ ^[0-9]+$ ]] && echo "$n" || echo 0
}

write_backoff_count() {
    ensure_cache_dir
    echo "$1" > "$BACKOFF_FILE" 2>/dev/null
}

calc_backoff_seconds() {
    local count="$1"
    local seconds=$(( DEFAULT_RATE_LIMIT_BACKOFF * (1 << count) ))
    [[ $seconds -gt 3600 ]] && seconds=3600
    echo "$seconds"
}

parse_retry_after() {
    local retry_after="$1"
    [[ -z "$retry_after" ]] && return 1
    if [[ "$retry_after" =~ ^[0-9]+$ ]]; then
        [[ $retry_after -gt 0 ]] && echo "$retry_after" && return 0
        return 1
    fi
    local retry_at_s
    retry_at_s=$(date -d "$retry_after" +%s 2>/dev/null)
    [[ -n "$retry_at_s" ]] || return 1
    local diff=$(( retry_at_s - $(date +%s) ))
    [[ $diff -gt 0 ]] && echo "$diff" && return 0
    return 1
}

fetch_from_api() {
    local token="$1"
    local response_file headers_file http_code
    response_file=$(mktemp)
    headers_file=$(mktemp)

    http_code=$(curl -s -m "$USAGE_API_TIMEOUT" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -w "%{http_code}" \
        -o "$response_file" \
        -D "$headers_file" \
        "https://${USAGE_API_HOST}${USAGE_API_PATH}" 2>/dev/null)

    local result=""
    if [[ "$http_code" == "200" ]]; then
        local body
        body=$(cat "$response_file" 2>/dev/null)
        [[ -n "$body" ]] && result="success:$body" || result="error"
    elif [[ "$http_code" == "429" ]]; then
        local retry_after retry_seconds
        retry_after=$(grep -i "^retry-after:" "$headers_file" | sed 's/^retry-after: *//i' | tr -d '\r\n' 2>/dev/null)
        retry_seconds=$(parse_retry_after "$retry_after")
        # 0 = no server hint; caller applies exponential backoff
        result="rate-limited:${retry_seconds:-0}"
    else
        result="error"
    fi

    rm -f "$response_file" "$headers_file"
    echo "$result"
}

parse_api_response() {
    local body="$1"
    jq -n --argjson data "$body" '{
        sessionUsage: $data.five_hour.utilization,
        sessionResetAt: $data.five_hour.resets_at,
        weeklyUsage: $data.seven_day.utilization,
        weeklyResetAt: $data.seven_day.resets_at,
        extraUsageEnabled: $data.extra_usage.is_enabled,
        extraUsageLimit: $data.extra_usage.monthly_limit,
        extraUsageUsed: $data.extra_usage.used_credits,
        extraUsageUtilization: $data.extra_usage.utilization
    }' 2>/dev/null
}

read_stale_cache() {
    [[ -f "$CACHE_FILE" ]] || return 1
    cat "$CACHE_FILE" 2>/dev/null
}

# Return stale cache only when it has no error and its sessionResetAt is absent
# or still in the future. Otherwise return 1 so callers fall through to an error
# response rather than lying about post-reset usage numbers.
stale_cache_if_valid() {
    local fallback_error="$1"
    local stale now_ts session_reset_at session_reset_epoch has_error
    stale=$(read_stale_cache) || return 1
    [[ -n "$stale" ]] || return 1
    has_error=$(echo "$stale" | jq -r '.error // empty' 2>/dev/null)
    [[ -n "$has_error" ]] && return 1
    session_reset_at=$(echo "$stale" | jq -r '.sessionResetAt // empty' 2>/dev/null)
    session_reset_epoch=0
    [[ -n "$session_reset_at" ]] && session_reset_epoch=$(date -d "$session_reset_at" +%s 2>/dev/null || echo 0)
    now_ts=$(now)
    if [[ $session_reset_epoch -eq 0 || $session_reset_epoch -gt $now_ts ]]; then
        echo "$stale"; return 0
    fi
    return 1
}

create_error_response() {
    echo "{\"error\":\"$1\"}"
}

fetch_usage_data() {
    local now_ts
    now_ts=$(now)

    # Cache check — also invalidate if sessionResetAt is in the past.
    if [[ -f "$CACHE_FILE" ]]; then
        local cache_age cached_data has_error session_reset_at session_reset_epoch session_pct
        cache_age=$(( now_ts - $(file_mtime "$CACHE_FILE") ))
        cached_data=$(cat "$CACHE_FILE" 2>/dev/null)
        if [[ -n "$cached_data" ]]; then
            has_error=$(echo "$cached_data" | jq -r '.error // empty' 2>/dev/null)
            session_reset_at=$(echo "$cached_data" | jq -r '.sessionResetAt // empty' 2>/dev/null)
            session_reset_epoch=0
            [[ -n "$session_reset_at" ]] && session_reset_epoch=$(date -d "$session_reset_at" +%s 2>/dev/null || echo 0)
            if [[ -z "$has_error" && ( $session_reset_epoch -eq 0 || $session_reset_epoch -gt $now_ts ) ]]; then
                # Normal TTL
                if [[ $cache_age -lt $CACHE_MAX_AGE ]]; then
                    echo "$cached_data"; return 0
                fi
                # Extended TTL (3×) when usage <50% and session reset >30 min away
                session_pct=$(echo "$cached_data" | jq -r '(.sessionUsage // 100) | floor' 2>/dev/null)
                if [[ $cache_age -lt $(( CACHE_MAX_AGE * 3 )) \
                      && "${session_pct:-100}" -lt 50 \
                      && $session_reset_epoch -gt $(( now_ts + 1800 )) ]]; then
                    echo "$cached_data"; return 0
                fi
            fi
        fi
    fi

    # Token
    local token
    token=$(get_usage_token)
    if [[ -z "$token" ]]; then
        stale_cache_if_valid "no-credentials" || { create_error_response "no-credentials"; return 1; }
        return 0
    fi

    # Lock
    local lock_info
    if lock_info=$(read_active_lock); then
        local lock_error="${lock_info%%:*}"
        stale_cache_if_valid "$lock_error" || { create_error_response "$lock_error"; return 1; }
        return 0
    fi

    write_lock $(( now_ts + LOCK_MAX_AGE )) "timeout"

    local api_result
    api_result=$(fetch_from_api "$token")
    local result_type="${api_result%%:*}"
    local result_value="${api_result#*:}"

    case "$result_type" in
        success)
            local usage_data
            usage_data=$(parse_api_response "$result_value")
            if [[ -z "$usage_data" ]]; then
                stale_cache_if_valid "parse-error" || { create_error_response "parse-error"; return 1; }
                return 0
            fi
            local has_session has_weekly
            has_session=$(echo "$usage_data" | jq -r '.sessionUsage // empty' 2>/dev/null)
            has_weekly=$(echo "$usage_data" | jq -r '.weeklyUsage // empty' 2>/dev/null)
            if [[ -z "$has_session" && -z "$has_weekly" ]]; then
                stale_cache_if_valid "parse-error" || { create_error_response "parse-error"; return 1; }
                return 0
            fi
            ensure_cache_dir
            write_backoff_count 0
            echo "$usage_data" > "$CACHE_FILE" 2>/dev/null
            echo "$usage_data"
            return 0
            ;;
        rate-limited)
            local backoff_secs
            if [[ "$result_value" -gt 0 ]] 2>/dev/null; then
                # Server gave Retry-After; respect it and reset backoff counter
                backoff_secs="$result_value"
                write_backoff_count 0
            else
                # No server hint; exponential backoff
                local count
                count=$(read_backoff_count)
                backoff_secs=$(calc_backoff_seconds "$count")
                write_backoff_count $(( count + 1 ))
            fi
            write_lock $(( now_ts + backoff_secs )) "rate-limited"
            stale_cache_if_valid "rate-limited" || { create_error_response "rate-limited"; return 1; }
            return 0
            ;;
        *)
            stale_cache_if_valid "api-error" || { create_error_response "api-error"; return 1; }
            return 0
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fetch_usage_data
fi
