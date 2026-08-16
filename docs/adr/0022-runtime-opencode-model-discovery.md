# 0022. OpenCode provider availability is discovered at process startup

## Context

Mocin's model inventory changes independently from Nix and the tracked OpenCode configuration.

OpenCode 1.18.16 loads global TypeScript plugins before materializing custom provider models, so a startup `config` hook can update runtime availability without rewriting authored configuration.

## Decision

`dotagents` owns the authored Mocin provider definition, curated metadata overrides, and discovery plugin source.

The plugin fetches the vendor model inventory when a new OpenCode process starts, requires a root object with a `models` array and boolean `active` fields, and requires a non-empty, unchanged `model` ID only for active entries.

The `total` field and unrelated vendor metadata are ignored because they are not consumed for availability.

The runtime model map is built only from the current inventory.

Universe delivers the plugin through a read-only out-of-store symlink and checks the resolved provider through OpenCode's debug configuration output.

Model discovery is never performed during Nix evaluation, builds, or activation.

The validated model ID list is persisted only as a last-known-good snapshot at `$XDG_STATE_HOME/opencode/mocin-models.json` or its default under `$HOME/.local/state`.

The snapshot contains no authored metadata and is used only when the remote request fails, times out, returns a non-success status, or returns invalid data.

Current tracked dotagents metadata is applied to IDs restored from the snapshot, so stale metadata cannot revive an unavailable model.

Remote success remains usable when snapshot persistence fails, and snapshot replacement is an atomic same-directory rename from a unique temporary file.

No systemd refresh timer exists because availability refreshes at the next OpenCode startup and a timer would create a second synchronization mechanism.

OpenCode is not forked because the pinned plugin hook satisfies the required runtime insertion point.

## Consequences

Remote inventory is the availability source of truth, tracked dotagents configuration is persistent intent, and the snapshot is resilience state only.

Mocin can be temporarily unavailable without preventing unrelated OpenCode providers from loading.

Doctor reports a broken integration when OpenCode cannot resolve a valid provider configuration or when Mocin has no runtime models and no valid fallback state.
