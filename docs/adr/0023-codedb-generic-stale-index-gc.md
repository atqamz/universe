# CodeDB generic stale-index garbage collection

Status: accepted

## Context

CodeDB 0.2.5839 creates a project store entry when its generic MCP server learns an absolute project root.

The entry records that root in `project.txt` under `.codedb/projects/<hash>`.

CodeDB exposes no supported project-scoped remove, forget, or unindex operation.

Any editor, agent, MCP client, or other CodeDB consumer can create an entry for an ephemeral worktree.

Doctor treats an entry whose recorded root no longer exists as unhealthy.

## Decision

The existing `codedb-prune` job is the primary and only generic stale-index garbage collector.

It scans the authoritative `project.txt` marker, retains unknown or malformed entries, rechecks the marker and project root immediately before deletion, and deletes only a regular child directory of the CodeDB project store.

The timer runs after fifteen minutes at startup and hourly thereafter with a ten-minute randomized delay and persistent catch-up.

The timer bounds the expected doctor-red window after an arbitrary ephemeral project disappears without assigning cleanup to an unrelated producer.

## Consequences

No producer-specific teardown is required or invented for CodeDB indexes.

The existing prune operation remains the single repair owner and also removes historical backlog.

The safety-net behavior is generic because the producer set is intentionally generic.

Malformed metadata and symlink entries remain available for inspection instead of becoming deletion targets.
