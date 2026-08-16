#!/usr/bin/env bash
set -euo pipefail

doctor_bin=$1

root=$(mktemp -d)

cleanup() {
  rm -rf -- "$root"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

make_home() {
  home="$root/home"
  mkdir -p "$home/.config/universe"
  cat >"$home/.config/universe/doctor.json" <<EOF
{
  "host": "fixture",
  "paths": [
    "universe/configs/dotfiles",
    "universe/configs/dotagents"
  ],
  "absentPaths": [],
  "symlinks": {
    ".config/foot/foot.ini": "universe/configs/dotfiles/foot/foot.ini",
    ".config/opencode/dynamic-models": "universe/configs/dotagents/opencode/dynamic-models",
    ".config/opencode/opencode.json": "universe/configs/dotagents/opencode/opencode.json"
  }
}
EOF
  mkdir -p "$home/universe/configs/dotfiles/foot"
  mkdir -p "$home/universe/configs/dotagents/opencode/dynamic-models"
  echo hi >"$home/universe/configs/dotfiles/foot/foot.ini"
  echo hi >"$home/universe/configs/dotagents/opencode/opencode.json"
  echo hi >"$home/universe/configs/dotagents/opencode/dynamic-models/engine.ts"
  # canonical live topology: managed links resolve into the universe subtrees
  mkdir -p "$home/.config/foot"
  mkdir -p "$home/.config/opencode"
  ln -s "$home/universe/configs/dotfiles/foot/foot.ini" "$home/.config/foot/foot.ini"
  ln -s "$home/universe/configs/dotagents/opencode/dynamic-models" "$home/.config/opencode/dynamic-models"
  ln -s "$home/universe/configs/dotagents/opencode/opencode.json" "$home/.config/opencode/opencode.json"
}

run_doctor() {
  home=$1
  set +e
  HOME="$home" UNIVERSE_DOCTOR_LAYOUT_ONLY=1 "$doctor_bin" >"$root/out" 2>&1
  code=$?
  set -e
  return $code
}

# Case A: neither legacy dir exists. Canonical checks pass, no legacy warning, no mutation.
make_home
run_doctor "$root/home"
code=$?
[ "$code" -eq 0 ] || fail "case A: expected exit 0, got $code"
grep -q "PASS: universe/configs/dotfiles present" "$root/out" 2>/dev/null || true
if grep -q "WARN: legacy ~/dotfiles" "$root/out"; then
  fail "case A: unexpected legacy dotfiles warning"
fi
if grep -q "WARN: legacy ~/dotagents" "$root/out"; then
  fail "case A: unexpected legacy dotagents warning"
fi
echo "case A ok"

# Case B: legacy dirs are clean git repos. Warnings only, exit success, repos unchanged.
make_home
for name in dotfiles dotagents; do
  git -C "$root/home" init -q "$name"
  git -C "$root/home/$name" config user.email test@example.com
  git -C "$root/home/$name" config user.name test
  echo "$name" >"$root/home/$name/README.md"
  git -C "$root/home/$name" add README.md
  git -C "$root/home/$name" commit -qm init
  head_before="$(git -C "$root/home/$name" rev-parse HEAD)"
  echo "$head_before" >"$root/home/$name-before"
done
run_doctor "$root/home"
code=$?
[ "$code" -eq 0 ] || fail "case B: expected exit 0, got $code"
grep -q "WARN: legacy ~/dotfiles checkout remains; runtime no longer uses it" "$root/out" || fail "case B: missing clean dotfiles warning"
grep -q "WARN: legacy ~/dotagents checkout remains; runtime no longer uses it" "$root/out" || fail "case B: missing clean dotagents warning"
for name in dotfiles dotagents; do
  [ "$(git -C "$root/home/$name" rev-parse HEAD)" = "$(cat "$root/home/$name-before")" ] || fail "case B: $name HEAD changed"
done
echo "case B ok"

# Case B2: clean but ahead/divergent (local commit not upstream). Warn with numbers, exit success.
make_home
for name in dotfiles dotagents; do
  git init -q -b main "$root/home/$name"
  git -C "$root/home/$name" config user.email test@example.com
  git -C "$root/home/$name" config user.name test
  echo one >"$root/home/$name/a"
  git -C "$root/home/$name" add a
  git -C "$root/home/$name" commit -qm one
  git -C "$root/home/$name" branch -m main
  git clone -q --shared "$root/home/$name" "$root/home/$name-upstream"
  git -C "$root/home/$name-upstream" config user.email test@example.com
  git -C "$root/home/$name-upstream" config user.name test
  git -C "$root/home/$name" remote add origin "$root/home/$name-upstream"
  git -C "$root/home/$name" fetch -q origin
  git -C "$root/home/$name" branch --set-upstream-to=origin/main main
  echo two >"$root/home/$name/b"
  git -C "$root/home/$name" add b
  git -C "$root/home/$name" commit -qm two
done
run_doctor "$root/home"
code=$?
[ "$code" -eq 0 ] || fail "case B2: expected exit 0, got $code"
grep -q "ahead by 1" "$root/out" || fail "case B2: missing ahead warning"
echo "case B2 ok"

# Case C: legacy git repos dirty/untracked. Strong warning, exit success if canonical healthy.
make_home
for name in dotfiles dotagents; do
  git init -q "$root/home/$name"
  git -C "$root/home/$name" config user.email test@example.com
  git -C "$root/home/$name" config user.name test
  echo tracked >"$root/home/$name/README.md"
  git -C "$root/home/$name" add README.md
  git -C "$root/home/$name" commit -qm init
done
echo "dirty change" >"$root/home/dotfiles/README.md"
echo "untracked file" >"$root/home/dotagents/new.txt"
run_doctor "$root/home"
code=$?
[ "$code" -eq 0 ] || fail "case C: expected exit 0, got $code"
grep -q "legacy ~/dotfiles checkout contains local changes" "$root/out" || fail "case C: missing dirty dotfiles warning"
grep -q "legacy ~/dotagents checkout contains local changes" "$root/out" || fail "case C: missing dirty dotagents warning"
[ -f "$root/home/dotagents/new.txt" ] || fail "case C: untracked file lost"
echo "case C ok"

# Case D: legacy paths exist but are not git repos. Warning, no deletion, exit success.
make_home
mkdir -p "$root/home/dotfiles" "$root/home/dotagents"
echo "keep me" >"$root/home/dotfiles/precious"
run_doctor "$root/home"
code=$?
[ "$code" -eq 0 ] || fail "case D: expected exit 0, got $code"
grep -q "legacy ~/dotfiles exists but is not a Git repository" "$root/out" || fail "case D: missing non-git dotfiles warning"
grep -q "legacy ~/dotagents exists but is not a Git repository" "$root/out" || fail "case D: missing non-git dotagents warning"
[ -f "$root/home/dotfiles/precious" ] || fail "case D: file lost"
echo "case D ok"

# Case E: a live symlink points at the old source. Explicit stale-target FAIL, nonzero, old dir unchanged.
make_home
git init -q "$root/home/dotfiles"
git -C "$root/home/dotfiles" config user.email test@example.com
git -C "$root/home/dotfiles" config user.name test
echo old >"$root/home/dotfiles/foot.ini"
git -C "$root/home/dotfiles" add foot.ini
git -C "$root/home/dotfiles" commit -qm init
head_before="$(git -C "$root/home/dotfiles" rev-parse HEAD)"
ln -sfn "$root/home/dotfiles/foot.ini" "$root/home/.config/foot/foot.ini"
run_doctor "$root/home"
code=$?
[ "$code" -ne 0 ] || fail "case E: expected nonzero, got 0"
grep -q "stale legacy target" "$root/out" || fail "case E: missing stale-target diagnostic"
[ "$(git -C "$root/home/dotfiles" rev-parse HEAD)" = "$head_before" ] || fail "case E: old dir changed"
[ "$(cat "$root/home/dotfiles/foot.ini")" = old ] || fail "case E: old file changed"
echo "case E ok"

echo "all migration doctor cases passed"
