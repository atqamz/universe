# 0012. Automation distinguishes skips from failures

## Context

The user-timer abstraction attaches a failure notifier, but a caller can defeat that contract by appending `|| true` or converting every failed pull into a successful exit.
That creates the worst operational state: automation looks healthy while it has stopped repairing the machine.

## Decision

Automation exits successfully only for expected non-actions, such as a dirty repo that must not be overwritten, an application that is currently running, or a lock held by another valid sync.

Broken repair work returns non-zero: authentication failures, failed network operations after their own retry policy, divergence, invalid encrypted data, registration failures, and similar conditions become failed systemd units.

`hand-install` is the named exception to the network half of that rule: it bootstraps a runtime-managed payload only when the binary is absent, so a failed download warns to stderr and exits successfully, and `universe.doctor.paths` reports the still-absent binary instead of a failed unit (`0011-explicit-update-ownership.md`).
A checksum verification failure there is still fatal, because that is not transient.

Activation-time work that should not block a rebuild uses `onActivation = "try"`; the underlying command still fails normally when systemd runs it later.

Retry policy belongs to systemd when practical. Long-running watchers detect events and trigger oneshot jobs rather than hiding retry loops internally.

`nix run .#doctor` combines generated declarative expectations with live system state. Lists of installed user timers/services come from evaluated Home Manager configuration; host-specific critical system services and timers are declared through `universe.doctor.*`.

## Consequence

A green unit means the repair actually succeeded or intentionally skipped.
