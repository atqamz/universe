# 0022. OpenCode runtime model discovery is generic and provider-scoped

## Context

Remote model inventories change independently from Nix and tracked OpenCode configuration.

OpenCode 1.18.16 runs plugin `config` hooks before it parses configured provider models.
Its local model map key and generated model `id` therefore provide separate boundaries for OpenCode selector compatibility and upstream API identity.

## Decision

`dotagents` owns provider intent, dynamic discovery declarations and adapters, callable model identity, and authored metadata.
Universe owns one stable delivery link and generic runtime health checks.

The shared dynamic discovery engine runs once at OpenCode startup for each configured provider.
Standard OpenAI-compatible providers use `<baseURL>/models`.
Vendor-specific protocols use narrow adapters that only validate fields consumed for availability.

Every discovered model has three explicit identities:

- the OpenCode provider ID, such as `mocin`;
- the OpenCode local selector ID, encoded to be slash-free when required by the pinned runtime;
- the exact callable upstream ID, such as `nr/deepseek-v4-flash-0731`.

The selector is derived deterministically from the callable ID with standard percent encoding.
The generated model record sets `id` to the callable ID, so OpenCode's AI SDK factory receives the original route and never the encoded selector.
Authored metadata is keyed by callable ID and is overlaid only on currently discovered or restored models.

Mocin derives callable IDs from active `provider` and `model` fields as `provider/model`.
Route identity, not the display model component alone, controls deduplication and active/inactive conflict detection.
Unconsumed Mocin fields such as `upstream`, `multiplier`, and `total` do not affect availability.

Each provider has its own last-known-good snapshot under `$XDG_STATE_HOME/opencode/dynamic-models/<provider>.json` or the equivalent default state directory.
Snapshots store exact callable IDs, the provider, source endpoint, and schema version only.
Remote success replaces a validated snapshot atomically through a unique same-directory temporary file.
Remote failure uses only a compatible provider snapshot.
A lossy legacy Mocin snapshot at `$XDG_STATE_HOME/opencode/mocin-models.json` is ignored rather than assigned a guessed route.

Discovery is runtime-only.
It never runs during Nix evaluation, builds, activation, or CI.
The engine does not read OpenCode auth storage, persist credentials, or claim authenticated discovery when the pinned provider hook exposes no safe credential context.

The first rollout keeps the old Universe-owned plugin link while the new dotagents configuration is unavailable.
After the dotagents change is live, a small Universe cleanup removes that obsolete link and registers the stable directory link as a doctor symlink contract.
This ordering avoids an intermediate broken OpenCode configuration while preserving one active discovery owner in the final state.

## Consequences

Adding a standard provider requires a provider declaration and normal OpenCode provider credentials, with no new Universe link, cache, daemon, Nix network operation, or generated model list.
Adding a non-standard provider requires only its declaration and narrow response adapter.

A provider with no remote inventory and no compatible snapshot has no dynamic models, while unrelated providers remain usable.
OpenCode restarts are the refresh boundary.
Rollback is a normal revert of the two PRs, with the old Mocin state left untouched for diagnosis but never reinterpreted.
