---
name: github-actions
description: Use when inspecting, rerunning, or cancelling GitHub Actions workflow runs or pull request checks.
---

# github-actions

1. List runs: `gh run list --limit 20`.
2. View a run: `gh run view <run-id>`.
3. Watch a run: `gh run watch <run-id>`.
4. Read failed logs: `gh run view <run-id> --log-failed`.
5. Show pull request checks: `gh pr checks <N>`.
6. Read the failure before rerunning. Do not rerun a deterministic failure.
7. Rerun failed jobs: `gh run rerun <run-id> --failed`.
8. Cancel: `gh run cancel <run-id>`.

Verify with `gh run view <run-id> --json status,conclusion`.
