# OpenCode visibility probes use disposable database state

Status: accepted

## Context

OpenCode 1.18.16 implements `debug skill` with the default instance-enabled command path.

That path eagerly bootstraps the project instance and opens the default SQLite database before the command emits its skill JSON.

The default database is `$XDG_DATA_HOME/opencode/opencode-stable.db` when the stable channel is selected.

OpenCode enables WAL and a five-second SQLite busy timeout, but concurrent fresh processes can still fail while creating the initial schema.

The failure is independent of skill-file parsing and can report an error from `CREATE TABLE workspace`.

`--pure` disables external plugins but does not skip instance bootstrap or database initialization.

OpenCode discovers external skills from the real home directory, while its supported `OPENCODE_DB=:memory:` override changes only the database filename.

## Decision

`no-mistakes-reconcile discover opencode` sets `OPENCODE_DB=:memory:` for its bounded `opencode debug skill --pure` probe.

The probe keeps the real `HOME`, OpenCode configuration, and `.agents` and `.claude` skill roots.

The probe does not take a Universe advisory lock around OpenCode, so it does not serialize interactive or unrelated OpenCode processes.

The exact pinned OpenCode binary is exercised in a regression check with concurrent repository probes, one raw OpenCode process, and a raw OpenCode batch using the same disposable database boundary.

The shared-database stress case remains upstream behavior rather than a repository test assertion because its failure depends on scheduler timing.

## Consequences

The visibility result is truthful for the filesystem contract being checked and does not depend on unrelated persistent project history.

The probe no longer contends with normal OpenCode sessions through the default database.

Raw OpenCode processes that choose the shared default database can still contend during concurrent first initialization; Universe does not globally serialize those legitimate sessions.

The two canonical skill files remain independently atomically replaced with temporary files and `mv` under the refresh writer lock.

The pair is updated sequentially, not as one filesystem-level atomic replacement.

External readers can observe either generation of each complete file, and the exact OpenCode contract accepts either canonical global root for the visibility check.
