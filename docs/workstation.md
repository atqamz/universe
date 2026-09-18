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
8. Install the sfx14 units: `omarchy-pkg-add python-nvidia-ml-py`, `sudo install -m644 ~/universe/hosts/sfx14/*.service /etc/systemd/system/`, `sudo install -m755 ~/universe/hosts/sfx14/sfx14-warp-wireguard /usr/local/bin/`, then `sudo systemctl enable --now sfx14-power-cap.service sfx14-gpu-cap.service` and `sudo systemctl enable sfx14-warp-wireguard.service`.
9. Join the tailnet and enable remote access: `omarchy-pkg-add tailscale`, `sudo systemctl enable --now tailscaled.service`, then register against the same OAuth client pavg15 uses:

   ```sh
   sudo tailscale up --ssh --operator=$USER --advertise-tags=tag:universe \
     --auth-key "$(sops -d --extract '["tailscale-oauth"]' ~/universe/modules/nixos/secrets/tailscale-oauth.sops.yaml)?ephemeral=false"
   ```

Do not seed `~/.config` from Universe. Let Omarchy own its defaults and migrations. Add a durable personal override only after it proves necessary, and keep its ownership separate from the Omarchy baseline.

## Remote access

sfx14 reaches pavg15, and is reached from the phone, over the tailnet only. Nothing is port-forwarded and no host firewall port is opened: when no direct path exists the traffic relays through DERP, which SSH tolerates. Both ends therefore have to be logged in and online on the tailnet.

Inbound SSH is Tailscale SSH, served by `tailscaled`. `sshd` stays disabled, so the machine listens on no SSH port at all and the tailnet policy alone decides who may connect.

sfx14 carries `tag:universe` and registers with the same OAuth client as pavg15, so a reinstall rejoins unattended and the node key never expires. The tag is what makes that possible: an auth key that does not expire has to come from an OAuth client, and an OAuth client can only issue keys for a tag.

An OAuth client mints ephemeral keys by default, and an ephemeral node is deleted from the tailnet shortly after it goes offline. That suits pavg15, which never goes offline, but a laptop would disappear every night, so the workstation key carries `?ephemeral=false`.

Tagging is only free on a fresh install. Re-authenticating an already registered user-owned node with `--advertise-tags` does not convert it: the coordination server creates a second machine, hands it a new tailnet IP, and names it `sfx14-1` while the stale entry keeps the name. Delete the old machine and rename the new one in the admin console afterwards.

The tag is also what grants access. A tagged node is not owned by a user, so the tailnet's `autogroup:self` SSH rule no longer covers sfx14; the rule that targets `tag:universe` does. Confirm that rule exists before tagging the machine, otherwise inbound SSH stops at the moment of re-registration. The same rule currently lets the other tailnet member's device SSH into tagged nodes, which now includes this laptop. Narrow that rule if it stops being acceptable.

Cloudflare WARP must not run MASQUE. Under MASQUE an inbound Tailscale SSH session authenticates and its small non-interactive probes complete, but the interactive channel never opens, so the client sits at "connecting" with no error and the symptom mimics a bad ACL or a stale host key. Read `journalctl -u tailscaled` and look for `starting pty command`: if probe sessions reach `Session complete` and no PTY session ever starts, the tunnel is on MASQUE.

The Zero Trust device profile pushes MASQUE and `warp-cli tunnel protocol` is a consumer-only override, so `sfx14-warp-wireguard.service` restates WireGuard whenever `warp-svc` starts. It runs at WARP start rather than on a timer because repairing is expensive: setting the preference does not move a running tunnel, the daemon brings the tunnel back up on the old protocol first, and it takes two or three reconnect cycles and about fifty seconds with no connectivity at all. A periodic timer would turn a protocol that cannot be held into a network outage every few minutes. Under systemd there is no TTY, so every `warp-cli` call needs `--accept-tos`; without it the daemon refuses each call with a message that reads like any other failure, and a reconciler that mistakes it for a stopped tunnel reports success while changing nothing.

Taildrop is the price: it only works between user-owned nodes, so tagging sfx14 ends file transfer with the phone. Use `scp` over the tailnet instead.

Verify after registration with `tailscale debug netmap`: the `SSHPolicy` principals must include the phone's tailnet IP.

## sfx14 power

The Acer Swift SFX14-72G cools badly. At a measured 15 W package draw the CPU still sits at 83 C and the chassis sensors at 70-77 C, so the caps below limit the damage rather than fix it. The real fix is cleaning the heatsink and repasting. There is no software fan control: no `fan*_input` or `pwm*` in hwmon, `acer-wmi` exposes nothing, and there is no `platform_profile`. The fan curve belongs entirely to the Acer EC.

`sfx14-power-cap.service` writes PL1 and PL2 to 15 W on `/sys/class/powercap/intel-rapl:0`, against a firmware default of 45 W and 80 W. The effective limit is the minimum of the MSR and MMIO RAPL domains, so writing the MSR domain alone is enough.

`sfx14-gpu-cap.service` reproduces what the retired NixOS configuration did to the RTX 4050: persistence mode on, graphics clocks locked to 210-1540 MHz, and a +200 MHz GPC VF offset so the locked clock runs at a lower voltage point. The offset needs `python-nvidia-ml-py`; `nvidia-smi` only exposes negative VF derate on GeForce. Persistence mode keeps the dGPU initialised, which costs a little idle power.

Both units reapply on resume through `WantedBy=suspend.target` plus `After=suspend.target`, because firmware restores its own defaults across a suspend cycle.

Voltage undervolting is not possible on this machine. The OC mailbox is locked: a write of MSR 0x150 returns no fault but the offset reads back as 0 mV, with Secure Boot disabled and kernel lockdown `[none]`. The retired NixOS configuration did not undervolt either, despite the name; its `services.undervolt` block only carried RAPL limits.

The units are copied into `/etc/systemd/system` rather than symlinked, because `/home` is a separate mount and systemd must read them before it is available. Re-run the install command after editing them here.

Power profile selection stays with Omarchy and `power-profiles-daemon`. Universe does not set it.

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
