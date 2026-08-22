#!/usr/bin/env bash
set -euo pipefail

entry=openrouter/api-key

if ! command -v pass >/dev/null 2>&1; then
  echo "claude-ox: pass is not available" >&2
  exit 1
fi

store="${PASSWORD_STORE_DIR:-$HOME/.password-store}"
if [ ! -f "$store/$entry.gpg" ]; then
  echo "claude-ox: pass entry '$entry' not found; provision it with 'pass insert $entry'" >&2
  exit 1
fi

secret="$(pass show "$entry")" || {
  echo "claude-ox: failed to read pass entry '$entry'; run 'pass show $entry' to inspect the error" >&2
  exit 1
}

key="${secret%%$'\n'*}"
unset secret

if [ -z "$key" ]; then
  echo "claude-ox: pass entry '$entry' has an empty first line" >&2
  exit 1
fi

export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$key"
export ANTHROPIC_API_KEY=""
export ANTHROPIC_DEFAULT_OPUS_MODEL="stealth/ox-alpha"
export ANTHROPIC_DEFAULT_SONNET_MODEL="stealth/ox-alpha"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="stealth/ox-alpha"
export CLAUDE_CODE_SUBAGENT_MODEL="stealth/ox-alpha"

exec claude --model "stealth/ox-alpha" "$@"
