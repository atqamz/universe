# 0018. The weekly Treehouse prune job is audit-only

## Context

Universe runs Treehouse's global prune command from a weekly user timer.
Treehouse v2.1.1 safely defaults to a dry run, but its prune predicate has no durable distinction between a valuable idle warm-pool worktree and a disposable completed worktree.
Its ancestry-based merge check also does not recognize squash merges.
An unattended deletion command can therefore remove reusable build state while retaining worktrees that should be reclaimed.

## Decision

The weekly Universe job runs `treehouse prune --all --verbose` without `--yes` and without `--prune-orphans`.
It remains a `services.userTimers` weekly timer with its existing persistence and randomized delay.
The job reports candidates, unsafe classifications, orphans, and reclaimable size for human review, but it never deletes worktrees.
Treehouse remains the owner of worktree lifecycle and merge classification.
Universe will not add pool exclusions, age heuristics, output parsing, forge queries, or a local squash-merge algorithm.

Re-enabling unattended deletion requires an explicit reviewed decision after upstream Treehouse can distinguish retained warm capacity from disposable worktrees and correctly handle the repository's squash-merge workflow.

## Consequence

Weekly accumulation remains observable through the service journal and failure notification.
Worktree deletion and orphan cleanup require a deliberate human invocation until the upstream semantics are sufficient for unattended use.
The squash-merge classification problem remains tracked in `kunchenguid/treehouse#85`, while this decision addresses the destructive automation in `atqamz/universe#37`.
