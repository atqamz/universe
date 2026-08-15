#!/usr/bin/env bash
set -euo pipefail

gpu_wrapper=$1
resume_script=$2
unit=$3
target_module=$4
target_smi=$5
target_version=$6

test_root=$(mktemp -d)
log="$test_root/gpu.log"
current_system="$test_root/current-system"
booted_system="$test_root/booted-system"
kernel_a="$test_root/kernel-a"
kernel_b="$test_root/kernel-b"
loaded_version_file="$test_root/loaded-nvidia-version"
module_version=${target_module#*/lib/modules/}
module_version=${module_version%%/*}
booted_module="$booted_system/kernel-modules/lib/modules/$module_version/kernel/drivers/video/nvidia.ko.xz"
booted_smi="$booted_system/sw/bin/nvidia-smi"
fake_smi="$test_root/nvidia-smi"
fake_python="$test_root/python3"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_equal() {
  local expected=$1
  local actual=$2
  local name=$3

  [ "$actual" = "$expected" ] || fail "$name: expected <$expected>, got <$actual>"
}

assert_log() {
  local expected=$1
  local name=${2:-GPU command log}
  local actual
  actual=$(cat "$log")
  assert_equal "$expected" "$actual" "$name"
}

assert_applied_log() {
  local lines=()
  mapfile -t lines <"$log"
  assert_equal 3 "${#lines[@]}" "APPLIED command count"
  assert_equal 'nvidia-smi -pm 1' "${lines[0]}" "APPLIED persistence command"
  assert_equal 'nvidia-smi -lgc 210,1540' "${lines[1]}" "APPLIED locked-clock command"
  case "${lines[2]}" in
  'python3 '*) ;;
  *) fail "APPLIED NVML command missing" ;;
  esac
}

run_command() {
  if "$@"; then
    last_rc=0
  else
    last_rc=$?
  fi
}

set_kernel() {
  rm -f "$booted_system/kernel"
  ln -s "$1" "$booted_system/kernel"
}

set_module_target() {
  rm -f "$booted_module"
  ln -s "$target_module" "$booted_module"
}

set_module_mismatch() {
  rm -f "$booted_module"
  printf 'different NVIDIA module artifact\n' >"$booted_module"
}

set_smi_target() {
  rm -f "$booted_smi"
  ln -s "$target_smi" "$booted_smi"
}

set_smi_mismatch() {
  rm -f "$booted_smi"
  printf 'different NVIDIA userspace artifact\n' >"$booted_smi"
}

reset_log() {
  : >"$log"
}

export UNIVERSE_GPU_CURRENT_SYSTEM="$current_system"
export UNIVERSE_GPU_BOOTED_SYSTEM="$booted_system"
export UNIVERSE_GPU_LOADED_NVIDIA_VERSION_FILE="$loaded_version_file"
export UNIVERSE_GPU_NVIDIA_SMI="$fake_smi"
export UNIVERSE_GPU_PYTHON="$fake_python"
export UNIVERSE_GPU_TEST_LOG="$log"
export UNIVERSE_GPU_PM_STATUS=0
export UNIVERSE_GPU_LGC_STATUS=0
export UNIVERSE_GPU_PYTHON_STATUS=0

mkdir -p "$current_system" "$booted_system" "$(dirname "$booted_module")" "$(dirname "$booted_smi")"
printf 'kernel A\n' >"$kernel_a"
printf 'kernel B\n' >"$kernel_b"
printf '%s\n' "$target_version" >"$loaded_version_file"
ln -s "$kernel_a" "$current_system/kernel"
ln -s "$kernel_a" "$booted_system/kernel"
set_module_target
set_smi_target

cat >"$fake_smi" <<'EOF'
#!/bin/sh
printf 'nvidia-smi %s\n' "$*" >> "$UNIVERSE_GPU_TEST_LOG"
case "${1:-} ${2:-}" in
  "-pm 1") exit "${UNIVERSE_GPU_PM_STATUS:-0}" ;;
  "-lgc 210,1540") exit "${UNIVERSE_GPU_LGC_STATUS:-0}" ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$fake_smi"

cat >"$fake_python" <<'EOF'
#!/bin/sh
printf 'python3 %s\n' "$*" >> "$UNIVERSE_GPU_TEST_LOG"
exit "${UNIVERSE_GPU_PYTHON_STATUS:-0}"
EOF
chmod +x "$fake_python"

grep -Fx 'Type=oneshot' "$unit"
grep -Fx 'RemainAfterExit=true' "$unit"
grep -Fx 'SuccessExitStatus=75' "$unit"
grep -Fq 'sfx14-power restore' "$resume_script"
resume_wrapper=$(grep -oE '/nix/store/[^[:space:]]+-gpu-undervolt-resume/bin/gpu-undervolt-resume' "$resume_script" | head -n 1)
[ -x "$resume_wrapper" ] || fail "generated resume helper is missing"

reset_log
run_command "$gpu_wrapper"
assert_equal 0 "$last_rc" "coherent GPU policy"
assert_applied_log

reset_log
set_kernel "$kernel_b"
run_command "$gpu_wrapper"
assert_equal 75 "$last_rc" "kernel generation mismatch"
[ ! -s "$log" ] || fail "kernel mismatch touched the GPU"
set_kernel "$kernel_a"

reset_log
set_module_mismatch
run_command "$gpu_wrapper"
assert_equal 75 "$last_rc" "NVIDIA module mismatch"
[ ! -s "$log" ] || fail "NVIDIA module mismatch touched the GPU"
set_module_target

reset_log
set_smi_mismatch
run_command "$gpu_wrapper"
assert_equal 75 "$last_rc" "NVIDIA userspace mismatch"
[ ! -s "$log" ] || fail "NVIDIA userspace mismatch touched the GPU"
set_smi_target

reset_log
printf '595.90.00\n' >"$loaded_version_file"
run_command "$gpu_wrapper"
assert_equal 75 "$last_rc" "loaded NVIDIA version mismatch"
[ ! -s "$log" ] || fail "loaded NVIDIA version mismatch touched the GPU"
printf '%s\n' "$target_version" >"$loaded_version_file"

reset_log
export UNIVERSE_GPU_CURRENT_SYSTEM="$test_root/missing-current-system"
export UNIVERSE_GPU_BOOTED_SYSTEM="$test_root/missing-booted-system"
export UNIVERSE_GPU_PM_STATUS=29
run_command "$gpu_wrapper"
assert_equal 29 "$last_rc" "unknown generation identity"
assert_log 'nvidia-smi -pm 1' "unknown generation identity"
export UNIVERSE_GPU_CURRENT_SYSTEM="$current_system"
export UNIVERSE_GPU_BOOTED_SYSTEM="$booted_system"
export UNIVERSE_GPU_PM_STATUS=0

reset_log
export UNIVERSE_GPU_PM_STATUS=17
run_command "$gpu_wrapper"
assert_equal 17 "$last_rc" "persistence-mode failure"
assert_log 'nvidia-smi -pm 1' "persistence-mode failure"
export UNIVERSE_GPU_PM_STATUS=0

reset_log
export UNIVERSE_GPU_LGC_STATUS=18
run_command "$gpu_wrapper"
assert_equal 18 "$last_rc" "locked-clock failure"
assert_log $'nvidia-smi -pm 1\nnvidia-smi -lgc 210,1540' "locked-clock failure"
export UNIVERSE_GPU_LGC_STATUS=0

reset_log
export UNIVERSE_GPU_PYTHON_STATUS=19
run_command "$gpu_wrapper"
assert_equal 19 "$last_rc" "NVML failure"
assert_applied_log
export UNIVERSE_GPU_PYTHON_STATUS=0

reset_log
run_command "$resume_wrapper"
assert_equal 0 "$last_rc" "resume APPLIED"

reset_log
set_kernel "$kernel_b"
run_command "$resume_wrapper"
assert_equal 0 "$last_rc" "resume DEFERRED"
[ ! -s "$log" ] || fail "resume DEFERRED touched the GPU"
set_kernel "$kernel_a"

reset_log
export UNIVERSE_GPU_PM_STATUS=23
run_command "$resume_wrapper"
assert_equal 23 "$last_rc" "resume FAILED"
export UNIVERSE_GPU_PM_STATUS=0

printf 'PASS: SFX14 GPU lifecycle\n'
