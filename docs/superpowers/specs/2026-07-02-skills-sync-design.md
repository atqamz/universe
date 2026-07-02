# Cross-Agent Skills Sync Design

## Goal

Centralize shared agent skills for OpenCode and Claude Code while keeping existing always-on behavior for caveman and ponytail.
Use the `skills` CLI through `bunx` for cross-agent installation and updates.
Keep the real RTK binary and hook setup separate from the `rtk-ai/rtk` skills package.

## Current State

OpenCode currently loads skills from multiple places.
`/home/atqa/dotagents/opencode/opencode.json` loads `superpowers` and `ponytail` as OpenCode plugins.
`/home/atqa/.config/opencode/skills/` contains local caveman and cavecrew skill directories.
`/home/atqa/.config/opencode/plugins/caveman/plugin.js` adds OpenCode-specific caveman state tracking and per-turn reinforcement.

`/home/atqa/dotagents/AGENTS.md` already contains always-on caveman and ponytail rules.
It also already references `@RTK.md` and tells agents to prefer `rtk <cmd>` for verbose CLI operations.

The real RTK binary is installed and verified as Rust Token Killer.
`rtk --version` reports `0.42.4`, `rtk gain` works, and the binary path is `/etc/profiles/per-user/atqa/bin/rtk`.

## Source Of Truth

Create `/home/atqa/dotagents/skills/manifest.txt` as the canonical skills source list.
It contains one source per line:

```text
juliusbrussee/caveman
dietrichgebert/ponytail
obra/superpowers
pbakaus/impeccable
kunchenguid/gh-axi
```

Do not include `rtk-ai/rtk` in this manifest.
That repository also publishes skills, but the desired RTK integration is the installed binary and Claude hook, not its skills pack.

## Sync Command

Add a Nix-managed user command named `skills-sync`.
It reads the manifest sequentially and installs every skill from each source into both OpenCode and Claude Code global skill directories.

The command for each source is:

```sh
bunx --yes skills add "$source" -g -a opencode -a claude-code --skill '*' -y
```

The command must run sources sequentially.
Parallel `bunx skills` calls can race in Bun's package cache and fail with missing extracted files.

## Auto-Update

Add a user systemd service and timer for `skills-sync`.
The timer runs shortly after user session startup and then daily.
This mirrors the existing `vault-sync` style and keeps skills current without manual intervention.

## Cleanup

After `skills-sync` succeeds once, remove replaced local skill and plugin setup.

Remove these OpenCode plugin entries from `/home/atqa/dotagents/opencode/opencode.json`:

```json
"superpowers@git+https://github.com/obra/superpowers.git"
"@dietrichgebert/ponytail"
"./plugins/caveman/plugin.js"
```

Delete the old local OpenCode skill directories before syncing so only `skills` CLI output remains under `/home/atqa/.config/opencode/skills/`.
This removes local caveman, cavecrew, and related caveman helper skill directories.

Delete `/home/atqa/.config/opencode/plugins/caveman/` because caveman behavior is now supplied by skills plus global always-on instructions.

## Preserved Behavior

Keep always-on caveman and ponytail policy in `/home/atqa/dotagents/AGENTS.md`.
Do not rely on skill auto-triggering alone for these two behaviors.

Keep `@RTK.md` and `Prefer rtk <cmd>` guidance in `/home/atqa/dotagents/AGENTS.md`.
Do not replace the real RTK binary integration with the `rtk-ai/rtk` skills package.

## Verification

Run `skills-sync` manually once.
Confirm OpenCode skills exist under `/home/atqa/.config/opencode/skills/`.
Confirm Claude Code skills exist under `/home/atqa/.claude/skills/`.
Confirm `cavecrew` comes from `juliusbrussee/caveman`.
Confirm OpenCode config no longer references removed plugin packages.
Run `nix fmt` and `nix flake check --no-build` in `/home/atqa/universe`.
Restart OpenCode and Claude Code because skills and config load at startup.
