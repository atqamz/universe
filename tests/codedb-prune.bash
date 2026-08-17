#!/usr/bin/env bash
set -euo pipefail

prune_script=${1:?usage: codedb-prune.bash SCRIPT}
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT
real_head=$(command -v head)
bash_path=$(command -v bash)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_exists() {
  [[ -e $1 || -L $1 ]] || fail "expected $1 to exist"
}

assert_absent() {
  [[ ! -e $1 && ! -L $1 ]] || fail "expected $1 to be absent"
}

assert_output_contains() {
  local file=$1
  local expected=$2
  grep -Fq "$expected" "$file" || fail "$file does not contain $expected"
}

assert_file_contains() {
  local file=$1
  local expected=$2
  grep -Fqx "$expected" "$file" || fail "$file does not contain $expected"
}

new_case() {
  case_root=$(mktemp -d "$test_root/case.XXXXXX")
  export CODEDB_HOME="$case_root/codedb"
  mkdir -p "$case_root/home" "$CODEDB_HOME/projects" "$case_root/outside"
}

make_index() {
  local name=$1
  local project=$2
  mkdir -p "$CODEDB_HOME/projects/$name"
  printf '%s\n' "$project" >"$CODEDB_HOME/projects/$name/project.txt"
}

run_prune() {
  local label=$1
  shift
  if ! HOME="$case_root/home" CODEDB_HOME="$CODEDB_HOME" bash "$prune_script" "$@" \
    >"$test_root/$label.stdout" 2>"$test_root/$label.stderr"; then
    cat "$test_root/$label.stdout" >&2
    cat "$test_root/$label.stderr" >&2
    fail "$label unexpectedly failed"
  fi
}

new_case
active="$case_root/active project"
stale="$case_root/missing project"
mkdir -p "$active"
make_index active "$active"
make_index stale "$stale"
before=$(find "$CODEDB_HOME/projects" -print | sort)
run_prune dry_run --dry-run
after=$(find "$CODEDB_HOME/projects" -print | sort)
[[ $before == "$after" ]] || fail 'dry-run changed the project store'
assert_output_contains "$test_root/dry_run.stdout" '1 stale indexes'
assert_exists "$CODEDB_HOME/projects/stale"
assert_exists "$CODEDB_HOME/projects/active"
run_prune stale_delete
assert_absent "$CODEDB_HOME/projects/stale"
assert_exists "$CODEDB_HOME/projects/active"

new_case
mkdir -p "$CODEDB_HOME/projects/no-marker" "$CODEDB_HOME/projects/empty-marker" "$CODEDB_HOME/projects/relative-marker" "$CODEDB_HOME/projects/unreadable-marker"
: >"$CODEDB_HOME/projects/empty-marker/project.txt"
printf 'relative/path\n' >"$CODEDB_HOME/projects/relative-marker/project.txt"
printf '%s\n' "$case_root/missing" >"$CODEDB_HOME/projects/unreadable-marker/project.txt"
chmod 000 "$CODEDB_HOME/projects/unreadable-marker/project.txt"
mkdir -p "$case_root/external-index"
printf '%s\n' "$case_root/missing-external" >"$case_root/external-index/project.txt"
ln -s "$case_root/external-index/project.txt" "$CODEDB_HOME/projects/linked-marker"
ln -s "$case_root/external-index" "$CODEDB_HOME/projects/linked-index"
: >"$CODEDB_HOME/projects/unrelated.txt"
run_prune malformed_metadata
assert_output_contains "$test_root/malformed_metadata.stdout" 'index directories without a readable project root'
for index in no-marker empty-marker relative-marker unreadable-marker linked-marker linked-index; do
  assert_exists "$CODEDB_HOME/projects/$index"
done
assert_exists "$CODEDB_HOME/projects/unrelated.txt"
assert_exists "$case_root/external-index/project.txt"

new_case
external_marker="$case_root/external-marker"
printf '%s\n' "$case_root/missing-marker-target" >"$external_marker"
mkdir -p "$CODEDB_HOME/projects/regular-index"
ln -s "$external_marker" "$CODEDB_HOME/projects/regular-index/project.txt"
run_prune symlink_project_marker
[[ -d $CODEDB_HOME/projects/regular-index ]] || fail 'regular index with a symlink marker was removed'
[[ -L $CODEDB_HOME/projects/regular-index/project.txt ]] || fail 'symlink project marker was replaced'
[[ $(readlink "$CODEDB_HOME/projects/regular-index/project.txt") == "$external_marker" ]] || fail 'symlink project marker target changed'
assert_exists "$external_marker"
assert_file_contains "$external_marker" "$case_root/missing-marker-target"

new_case
active_real="$case_root/active-real"
active_link="$case_root/active-link"
mkdir -p "$active_real"
ln -s "$active_real" "$active_link"
make_index active-link "$active_link"
mkdir -p "$case_root/outside/untouched"
make_index 'stale with spaces' "$case_root/missing spaces"
make_index '-stale-leading-dash' "$case_root/missing-leading-dash"
make_index containment "$case_root/outside/missing"
run_prune multiple_stale
assert_absent "$CODEDB_HOME/projects/stale with spaces"
assert_absent "$CODEDB_HOME/projects/-stale-leading-dash"
assert_absent "$CODEDB_HOME/projects/containment"
assert_exists "$CODEDB_HOME/projects/active-link"
assert_exists "$case_root/outside/untouched"

new_case
recreated="$case_root/recreated-before-delete"
make_index recreated "$recreated"
mkdir -p "$case_root/bin"
: >"$case_root/head-count"
cat >"$case_root/bin/head" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count=$(cat "$FAKE_HEAD_COUNT_FILE")
count=$((count + 1))
printf '%s\n' "$count" >"$FAKE_HEAD_COUNT_FILE"
if ((count == 2)); then
  mkdir -p "$FAKE_RECREATED_PROJECT"
fi
exec "$REAL_HEAD" "$@"
EOF
chmod +x "$case_root/bin/head"
sed -i "1c#!$bash_path" "$case_root/bin/head"
printf '0\n' >"$case_root/head-count"
if ! HOME="$case_root/home" CODEDB_HOME="$CODEDB_HOME" PATH="$case_root/bin:$PATH" \
  FAKE_HEAD_COUNT_FILE="$case_root/head-count" FAKE_RECREATED_PROJECT="$recreated" \
  REAL_HEAD="$real_head" bash "$prune_script" >"$test_root/recreated.stdout" 2>"$test_root/recreated.stderr"; then
  cat "$test_root/recreated.stdout" >&2
  cat "$test_root/recreated.stderr" >&2
  fail 'recreated project prune unexpectedly failed'
fi
assert_exists "$CODEDB_HOME/projects/recreated"
if [[ ! -e $recreated ]]; then
  fail "expected $recreated to exist"
fi
assert_output_contains "$test_root/recreated.stdout" 'exists again; keeping'

printf 'PASS: codedb prune lifecycle\n'
