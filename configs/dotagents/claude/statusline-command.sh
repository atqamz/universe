#!/usr/bin/env bash
C_RESET='\033[0m'
C_GRAY='\033[38;5;245m'
C_ACCENT='\033[38;5;74m'

input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // .model.id // "?"' | sed 's/ ([0-9]*[KMkm] context)$//')
MODEL_ID=$(echo "$input" | jq -r '.model.id')
cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd" 2>/dev/null || echo "?")

branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
USAGE=$(echo "$input" | jq '.context_window.current_usage')
max_k=$((CONTEXT_SIZE / 1000))

if [ "$max_k" -ge 1000 ]; then
  ctx_label="$((max_k / 1000))M context"
else
  ctx_label="${max_k}K context"
fi

MAX_OUTPUT_CAP=20000
case "$MODEL_ID" in
*opus-4-6*) MODEL_MAX=128000 ;;
*opus-4-5* | *sonnet-4* | *haiku-4*) MODEL_MAX=64000 ;;
*opus-4*) MODEL_MAX=32000 ;;
*3-5*) MODEL_MAX=8192 ;;
*claude-3-opus*) MODEL_MAX=4096 ;;
*claude-3-sonnet*) MODEL_MAX=8192 ;;
*claude-3-haiku*) MODEL_MAX=4096 ;;
*) MODEL_MAX=32000 ;;
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

dir_part="${C_GRAY}${dir}"
[ -n "$branch" ] && dir_part="${dir_part} (${branch})"
line1="${C_ACCENT}${model}${C_GRAY} (${ctx_label})${C_RESET} ${C_GRAY}|${C_RESET} ${dir_part}${C_RESET}"

I_CLOCK=$''
I_CAL=$''
I_RELOAD=$''

I_BRAIN=$''

usage_core=""
usage_script="$(dirname "${BASH_SOURCE[0]}")/fetch-usage.sh"
if [ -f "$usage_script" ]; then
  # shellcheck source=/dev/null
  source "$usage_script"
  usage_json=$(fetch_usage_data 2>/dev/null)
  if [ -n "$usage_json" ] && [ -z "$(echo "$usage_json" | jq -r '.error // empty' 2>/dev/null)" ]; then
    s_pct=$(echo "$usage_json" | jq -r 'if .sessionUsage == null then "" else (.sessionUsage | floor) end' 2>/dev/null)
    w_pct=$(echo "$usage_json" | jq -r 'if .weeklyUsage == null then "" else (.weeklyUsage | floor) end' 2>/dev/null)
    reset_at=$(echo "$usage_json" | jq -r '.sessionResetAt // empty' 2>/dev/null)
    reset_hm=""
    [ -n "$reset_at" ] && reset_hm=$(date -d "$reset_at" +%H.%M 2>/dev/null)
    sep=""
    [ -n "$s_pct" ] && {
      usage_core="${usage_core}${sep}${I_CLOCK} $(printf '%02d' "$s_pct")%"
      sep="  "
    }
    [ -n "$w_pct" ] && {
      usage_core="${usage_core}${sep}${I_CAL} $(printf '%02d' "$w_pct")%"
      sep="  "
    }
    [ -n "$reset_hm" ] && {
      usage_core="${usage_core}${sep}${I_RELOAD} ${reset_hm}"
      sep="  "
    }
    [ -n "$usage_core" ] && usage_core="${C_GRAY}${usage_core}${C_RESET}"
  fi
fi

EFFORT=$(echo "$input" | jq -r '.effort.level // empty')
THINKING=$(echo "$input" | jq -r '.thinking.enabled')
FAST=$(echo "$input" | jq -r '.fast_mode')

effort_seg=""
if [ -n "$EFFORT" ]; then
  case "$EFFORT" in
  low) C_EFF="$C_GRAY" ;;
  medium) C_EFF='\033[32m' ;;
  high) C_EFF='\033[33m' ;;
  xhigh | max) C_EFF='\033[31m' ;;
  *) C_EFF="$C_GRAY" ;;
  esac
  effort_seg="${C_EFF}${EFFORT}${C_RESET}"
  [ "$FAST" = "true" ] && effort_seg="${effort_seg} ${C_ACCENT}fast${C_RESET}"
  [ "$THINKING" = "false" ] && effort_seg="${effort_seg} ${C_GRAY}nothink${C_RESET}"
fi

brain_seg="${C_GRAY}${I_BRAIN}${C_RESET} ${C_CTX}${pct_prefix}${tokens_label}${C_RESET}"

line2=""
for seg in "$usage_core" "$effort_seg" "$brain_seg"; do
  [ -z "$seg" ] && continue
  [ -n "$line2" ] && line2="${line2} ${C_GRAY}|${C_RESET} "
  line2="${line2}${seg}"
done

printf '%b\n%b\n' "$line1" "$line2"
