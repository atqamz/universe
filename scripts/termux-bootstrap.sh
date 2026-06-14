#!/data/data/com.termux/files/usr/bin/bash
# Termux bootstrap: make a fresh phone reachable over SSH and pleasant to type in.
#
# Run on a new phone (Termux from any source):
#   bash <(curl -fsSL https://raw.githubusercontent.com/atqamz/universe/master/scripts/termux-bootstrap.sh)
#
# Idempotent: safe to re-run. Does NOT touch Nix (Termux can't host a Nix store).
# After running, laptops connect with `ssh phone` (port 8022).
set -euo pipefail

[ -n "${PREFIX:-}" ] && [ -d "$PREFIX" ] || {
  echo "Not running inside Termux (\$PREFIX unset). Aborting." >&2
  exit 1
}

GH_USER="atqamz"
BASHRC="$HOME/.bashrc"
MARK="# >>> termux-bootstrap >>>"

log() { printf '\n==> %s\n' "$1"; }

# --- packages --------------------------------------------------------------
log "Installing openssh"
yes | pkg update >/dev/null 2>&1 || true
pkg install -y openssh >/dev/null

# --- authorized_keys -------------------------------------------------------
log "Fetching authorized_keys from github.com/$GH_USER.keys"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
auth="$HOME/.ssh/authorized_keys"
touch "$auth"
chmod 600 "$auth"
keys="$(curl -fsSL "https://github.com/$GH_USER.keys")"
[ -n "$keys" ] || { echo "No keys returned for $GH_USER" >&2; exit 1; }
while IFS= read -r key; do
  [ -n "$key" ] || continue
  grep -qxF "$key" "$auth" || echo "$key" >>"$auth"
done <<<"$keys"

# --- persistent bashrc block (wakelock + sshd autostart) -------------------
log "Wiring wakelock + sshd autostart into $BASHRC"
touch "$BASHRC"
if ! grep -qF "$MARK" "$BASHRC"; then
  cat >>"$BASHRC" <<'EOF'

# >>> termux-bootstrap >>>
# Hold a wakelock so Android Doze can't freeze sshd while the screen is off.
termux-wake-lock 2>/dev/null || true
# Start sshd (listens on 8022) if not already running.
pgrep -x sshd >/dev/null 2>&1 || sshd
# <<< termux-bootstrap <<<
EOF
fi

# --- extra-keys bottom bar -------------------------------------------------
log "Configuring extra-keys bottom bar"
mkdir -p "$HOME/.termux"
props="$HOME/.termux/termux.properties"
[ -f "$props" ] && cp "$props" "$props.bak.$$"
# Strip any prior extra-keys block, then append ours.
if [ -f "$props" ]; then
  sed -i '/^extra-keys/,/]$/d' "$props"
fi
cat >>"$props" <<'EOF'
extra-keys = [ \
 ['ESC','TAB','CTRL','ALT','SHIFT','/','-','|','~','HOME'], \
 ['KEYBOARD','PGUP','UP','PGDN','DEL','LEFT','DOWN','RIGHT','END','ENTER'] \
]
EOF
termux-reload-settings 2>/dev/null || true

# --- start services now ----------------------------------------------------
log "Acquiring wakelock + starting sshd"
termux-wake-lock 2>/dev/null || true
pgrep -x sshd >/dev/null 2>&1 || sshd

# --- summary ---------------------------------------------------------------
ip="$(ip route get 1 2>/dev/null | awk '{print $7; exit}' || true)"
cat <<EOF

Done. SSH in from a laptop with:
    ssh ${USER}@${ip:-<phone-ip>} -p 8022

User: ${USER}   Port: 8022
Reminder: set Android battery to 'Unrestricted' for Termux (and Tailscale)
so Doze never kills the connection.
EOF
