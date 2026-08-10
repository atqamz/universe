# 0015. One owner for AI harness integration

## Context

Three coding harnesses run on this workstation: Claude Code, Codex, and OpenCode.
Each wants the same integrations registered - the `codedb` and `qmd` MCP servers, the RTK shell proxy, herdr agent-state hooks, and a shared skill set - and each has a different registration format and a different notion of who may write its config.

Before this decision the registrations had accumulated four different owners.
A daily Home Manager timer patched `~/.claude.json` with `jq` to register `codedb` for Claude only, so Codex and OpenCode never saw it.
`rtk-init.timer` re-ran an imperative installer to place a plugin file that Nix can place directly.
`herdr integration install` was expected to be re-run by hand, and its three asset versions drifted independently.
The skill allowlist lived in `dotagents/skills/manifest.txt` while the sync command that consumed it lived in Nix, so neither file was authoritative.
The net effect was that "the machine rebuilt successfully" said nothing about whether any harness could actually reach any integration.

The obstacle is that the harnesses do not agree on writability.

- OpenCode reads a plain tracked config file. Universe can express the whole `mcp` block declaratively in `dotagents/opencode/opencode.json`.
- Codex owns `~/.codex/config.toml` and rewrites it for `codex mcp add` and for per-project trust entries. It cannot be a store symlink, and `codex --enable hooks` is per-invocation only, so `[features] hooks = true` has to be persisted in that same file.
- Claude Code has no supported user-scope MCP config file at all. `~/.claude.json` is a 219 KB mutable state file holding startup counts and per-project history alongside `mcpServers`.

## Decision

One Home Manager module, `modules/home/ai-harness.nix`, owns the cross-harness vocabulary.
Feature modules declare `universe.aiHarness.mcpServers.<name> = { command; args; env; }` once, and `universe.aiHarness.codexConfig` for Codex keys Universe claims.
The module renders the per-harness shapes from that single attrset and ships one `ai-harness-reconcile` command.

Reconcile is a runtime-managed payload under `0011-explicit-update-ownership.md`, not an escape from it.
Universe still declares the desired content, the installer, and the repair mechanism; only the final write happens at runtime because the target files are application-owned.

- Claude: `jq '.mcpServers = $desired[0]'` replaces exactly that key and preserves the rest. If `~/.claude.json` is not valid JSON the command exits non-zero rather than clobbering it.
- Codex: a `tomlkit` merge deletes the Universe-owned paths, then merges the declared patch. `[projects.*]` trust entries and the user's `model` survive.
- OpenCode: no runtime step. The `mcp` block is tracked config, and doctor enforces it.

Everything that can be a plain file is a plain file.
The RTK OpenCode plugin comes from `pkgs.rtk.src`, so it is pinned to the same revision as the `rtk` binary.
The herdr hooks come from the pinned `herdr` flake input at the exact asset paths its `integration status` inspects, which is why `herdr integration install` never has to run.
The skill allowlist is a Nix attrset naming each source repository and each wanted skill, replacing `dotagents/skills/manifest.txt`; upstream additions do not silently enter the global prompt surface.
Installing that allowlist is not enough to make it authoritative, because `bunx skills add` has no notion of what Universe asked for last time.
`skills-sync` therefore keeps a ledger at `$XDG_STATE_HOME/universe/managed-skills` naming the skills it managed on its last successful run, and retires `previous - current` from the three roots this delivery mechanism writes before installing.
Ownership comes from the ledger, never from a directory merely existing under `~/.agents/skills`, which is what keeps an independently managed skill such as `no-mistakes` safe.
The ledger is replaced atomically after the sync succeeds, so a failed sync retries the same retirement instead of forgetting it.

Every one of these gains a doctor contract.
`universe.doctor` grew `commands`, `paths`, `absentPaths`, `mcpServers`, `herdrIntegrations`, `qmdCollections`, `expectedSkills`, and `forbiddenSkills`, and the checks are derived from the same declarations the modules already make.

## Consequence

Adding an MCP server is one `universe.aiHarness.mcpServers` entry plus one line in the OpenCode config, and all three harnesses plus doctor follow.
Removing one removes it from all three, because the Claude and Codex writes are replace semantics over the owned key, not merges.

Doctor asks the harnesses rather than reading their files: `opencode debug config`, `opencode debug skill`, `codex mcp list --json`, `herdr integration status`, `qmd status`.
`opencode debug config` exits 0 even on invalid config, so the check tests that its output is parseable JSON instead of trusting the exit code.

Two consequences are worth stating because they look like mistakes.

`~/.config/qmd/index.yml` uses `.yml`, against the repo rule that YAML files are `.yaml`.
qmd resolves that exact filename, so the name is upstream's, not a choice.

Reconcile runs on activation with `onActivation = "try"` and once at boot, so a rebuild does not fail on an application-owned file, but the same command still fails visibly under systemd per `0012-automation-failures-are-observable.md`.
