# Omarchy workstation

The workstation is expected to look like a fresh current Omarchy install plus identity, secrets, personal agent policy, and project repositories. Reinstalling does not attempt to reproduce every desktop preference.

## Bootstrap

1. Complete normal Omarchy installation and onboarding.
2. Authenticate GitHub with `gh auth login`.
3. Clone the private Vault: `gh repo clone atqamz/vault ~/vault`.
4. Run `~/vault/scripts/bootstrap-workstation` to restore personal identity and password-store.
5. Clone Universe: `git clone git@github.com:atqamz/universe.git ~/universe`.
6. Run `~/universe/agents/link`.
7. Install Nix only for repositories that use it: `omarchy-pkg-add nix`, then `sudo systemctl enable --now nix-daemon.service`.

Do not seed `~/.config` from Universe. Let Omarchy own its defaults and migrations. Add a durable personal override only after it proves necessary, and keep its ownership separate from the Omarchy baseline.

## Agents

Universe owns only:

- `agents/global.md`: personal defaults shared across Claude Code, Codex, and OpenCode.
- `agents/skills/*`: personally authored reusable skills such as `gh-ops`.
- `agents/update-skills`: refreshes mandatory externally owned skills from their canonical skills.sh/GitHub sources.

`agents/link` links files and individual personally owned skill directories. It never replaces an existing real file or a foreign symlink, and it never replaces whole harness directories such as `~/.claude`, `~/.codex`, `~/.config/opencode`, or `~/.agents/skills`.

For software engineering work, `caveman` and `ponytail` are mandatory personal policy. Universe also installs the complete Superpowers suite. These skills remain externally owned rather than vendored into Universe:

- `caveman` comes from `JuliusBrussee/caveman`.
- `ponytail` comes from `DietrichGebert/ponytail`.
- The complete Superpowers suite comes from `obra/superpowers`.

Running `agents/link` installs or refreshes all configured external skills immediately and enables `universe-agent-skills-update.timer`. The user timer refreshes them once a week with `skills@1.5.25`; the skill contents still track their upstream sources, and new Superpowers skills are included automatically. Run `~/.local/bin/universe-update-agent-skills` for an immediate manual refresh.

Project-specific instructions belong in the project. Prefer `AGENTS.md` as the canonical project policy and a small `CLAUDE.md` that imports it when Claude compatibility is needed.
