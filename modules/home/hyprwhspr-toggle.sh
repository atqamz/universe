#!/usr/bin/env bash
set -euo pipefail

recording_state() {
  local status
  status="$(hyprwhspr record status 2>/dev/null)" || return 1
  case "$status" in
  *"Recording in progress"*) printf '%s\n' recording ;;
  *"Status: Idle"*) printf '%s\n' idle ;;
  *) return 1 ;;
  esac
}

notify() {
  if ! notify-send -a hyprwhspr -t 1500 "Voice typing" "$1"; then
    printf '%s\n' 'hyprwhspr-toggle: notification failed' >&2
  fi
}

before="$(recording_state)" || {
  notify 'Unable to read recording state'
  exit 1
}

hyprwhspr record toggle >/dev/null 2>&1 || {
  notify 'Could not toggle recording'
  exit 1
}

expected=idle
if [ "$before" = idle ]; then
  expected=recording
fi

for ((attempt = 0; attempt < 20; attempt++)); do
  current="$(recording_state 2>/dev/null || true)"
  if [ "$current" = "$expected" ]; then
    if [ "$current" = recording ]; then
      notify 'Recording started'
    else
      notify 'Transcribing...'
    fi
    exit 0
  fi
  sleep 0.05
done

notify 'Recording state did not change'
exit 1
