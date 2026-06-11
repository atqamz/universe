#!/usr/bin/env bash
# Claude Code detailed statusline
#
# Line 1: Model (context size)
# Line 2: tokens (pct%) | dir (branch)
#
# Usage limits (5hr + weekly) live in the waybar custom/claude_usage
# module now — no point showing them twice.

COLOR="blue"

C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
case "$COLOR" in
    orange)   C_ACCENT='\033[38;5;173m' ;;
    blue)     C_ACCENT='\033[38;5;74m' ;;
    teal)     C_ACCENT='\033[38;5;66m' ;;
    green)    C_ACCENT='\033[38;5;71m' ;;
    lavender) C_ACCENT='\033[38;5;139m' ;;
    rose)     C_ACCENT='\033[38;5;132m' ;;
    gold)     C_ACCENT='\033[38;5;136m' ;;
    slate)    C_ACCENT='\033[38;5;60m' ;;
    cyan)     C_ACCENT='\033[38;5;37m' ;;
    *)        C_ACCENT="$C_GRAY" ;;
esac

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"' | sed 's/ ([0-9]*[KMkm] context)$//')
MODEL_ID=$(echo "$input" | jq -r '.model.id')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")
session=$(echo "$input" | jq -r '.session_id // empty')

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

# -- Context window -----------------------------------------------------------

CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USAGE=$(echo "$input" | jq '.context_window.current_usage')
REMAINING_PCT=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
max_k=$((CONTEXT_SIZE / 1000))

# Human-readable context size (e.g. "200K", "1M")
if [ "$max_k" -ge 1000 ]; then
    ctx_label="$((max_k / 1000))M context"
else
    ctx_label="${max_k}K context"
fi

MAX_OUTPUT_CAP=20000
case "$MODEL_ID" in
    *opus-4-6*)                          MODEL_MAX=128000 ;;
    *opus-4-5*|*sonnet-4*|*haiku-4*)     MODEL_MAX=64000 ;;
    *opus-4*)                            MODEL_MAX=32000 ;;
    *3-5*)                               MODEL_MAX=8192 ;;
    *claude-3-opus*)                     MODEL_MAX=4096 ;;
    *claude-3-sonnet*)                   MODEL_MAX=8192 ;;
    *claude-3-haiku*)                    MODEL_MAX=4096 ;;
    *)                                   MODEL_MAX=32000 ;;
esac
[ "$MODEL_MAX" -lt "$MAX_OUTPUT_CAP" ] && MAX_OUTPUT=$MODEL_MAX || MAX_OUTPUT=$MAX_OUTPUT_CAP

EHA=$((CONTEXT_SIZE - MAX_OUTPUT))
THRESHOLD=$((EHA - 13000))

AUTOCOMPACT_ENABLED=1
if [ -f "$HOME/.claude.json" ]; then
    cfg_val=$(jq -r 'if has("autoCompactEnabled") then .autoCompactEnabled else true end' "$HOME/.claude.json" 2>/dev/null)
    [ "$cfg_val" = "false" ] && AUTOCOMPACT_ENABLED=0
fi
[ "$AUTOCOMPACT_ENABLED" = "1" ] && EFFECTIVE=$THRESHOLD || EFFECTIVE=$EHA

pct_prefix=""
if [ "$USAGE" != "null" ] && [ -n "$USAGE" ]; then
    CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    pct=$((CURRENT_TOKENS * 100 / EFFECTIVE))
    [ "$pct" -gt 100 ] && pct=100
else
    CURRENT_TOKENS=20000
    pct=$((20000 * 100 / EFFECTIVE))
    pct_prefix="~"
fi

# Human-readable token count (e.g. "45.2K", "1.3M")
if [ "$CURRENT_TOKENS" -ge 1000000 ]; then
    tokens_label=$(awk "BEGIN{printf \"%.1fM\", $CURRENT_TOKENS/1000000}")
elif [ "$CURRENT_TOKENS" -ge 1000 ]; then
    tokens_label=$(awk "BEGIN{printf \"%.1fK\", $CURRENT_TOKENS/1000}")
else
    tokens_label="$CURRENT_TOKENS"
fi

if [ "$pct" -lt 50 ]; then
    C_CTX='\033[32m'
elif [ "$pct" -lt 65 ]; then
    C_CTX='\033[33m'
elif [ "$pct" -lt 80 ]; then
    C_CTX='\033[38;5;208m'
else
    C_CTX='\033[31m'
fi

# -- GSD context bridge (for context-monitor hook) ----------------------------

if [ -n "$session" ]; then
    printf '{"session_id":"%s","remaining_percentage":%s,"used_pct":%d,"tokens":%d,"timestamp":%d}' \
        "$session" "${REMAINING_PCT:-0}" "$pct" "$CURRENT_TOKENS" "$(date +%s)" \
        > "/tmp/claude-ctx-${session}.json" 2>/dev/null
fi

# -- Output -------------------------------------------------------------------

# Line 1: Model (context size)
line1="${C_ACCENT}${model}${C_GRAY} (${ctx_label})${C_RESET}"

# Line 2: progress bar pct% | dir (branch)
dir_part="${C_GRAY}${dir}"
[ -n "$branch" ] && dir_part="${dir_part} (${branch})"
line2="${C_CTX}${pct_prefix}${tokens_label} (${pct}%)${C_RESET} ${C_GRAY}|${C_RESET} ${dir_part}${C_RESET}"

printf '%b\n%b\n' "$line1" "$line2"
