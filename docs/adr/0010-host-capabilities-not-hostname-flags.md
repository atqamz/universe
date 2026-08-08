# 0010. Shared modules consume capabilities, not hostname flags

## Context

A hostname is an identity, not a feature API.
Checking `hostname == "sfx14"` inside shared modules made the name implicitly mean ambient-light sensor, Zen writer, display topology, and other unrelated properties.
That coupling becomes invisible as hosts evolve or a third machine is added.

## Decision

Host-specific facts are declared as typed `universe.*` NixOS options.
Shared Home Manager modules read those facts through `osConfig`.

Examples:

- `universe.capabilities.ambientLight`
- `universe.roles.zenProfileWriter`

The `hostname` special argument remains available only where the identity itself is the data, such as selecting a host-specific dotfile.

## Consequence

A shared module can be reused by any future host by declaring the required capability or role.
Adding a hostname comparison to a shared module requires a reason that truly depends on identity rather than hardware or responsibility.
