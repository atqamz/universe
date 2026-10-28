---
name: secret-guard
description: Use when installing, checking or testing the Claude Code guard that keeps secrets out of agent transcripts - an output scrubber hook, deny rules, and the environment scrub settings. Run `guard doctor` to see whether the guard is active in the current session.
---

# secret-guard

A second line of defence against **accidental** disclosure: a command the agent runs for a legitimate reason prints a credential, and the value lands in the model context, the transcript `.jsonl` and every hook consumer. It is a net, not a wall. An agent that can run arbitrary commands as the operator's uid can still reach any value that uid can read. The real boundary is that the agent never holds the value or the key that decrypts it.

Universe does not own harness settings. Nothing here writes to `~/.claude`, `~/.codex` or any settings file. `guard install` prints the settings and the operator merges them.

Files, `$SKILL` being this directory:

| File | Does |
|---|---|
| `scrub` | Hook. Default: PostToolUse scrubber. `--wrap`: PreToolUse Bash wrapper. `--payload`: scrubs a whole hook payload on stdin to stdout, for forwarders. |
| `guard install` | Prints the settings JSON to merge. Hook paths point at this directory. |
| `guard doctor` | Reports whether the guard is configured and live in the current session. Exit 0 only when it is complete. |
| `test` | Unit tests with fake values. Runs in `nix flake check`. |
| `e2e` | Scripted `claude -p` sessions in scratch projects. Proves what reaches the transcript. Costs a few Haiku calls. |

## Install (operator)

1. `$SKILL/guard install` and merge the printed `hooks` and `permissions.deny` into `~/.claude/settings.json`. Keep the existing Orca hook entries, and add these entries next to them.
2. Start a new session and have the agent run `$SKILL/guard doctor`. The last line must read `canary: [redacted:github-token]`. If the agent sees a `ghp_SecretGuardCanary...` value instead, the hook is not active in that session.
3. Optional, read the environment section first: the env scrub and the Codex keys.

`python3` must be on `PATH` for hooks. Each hook has a 10 s timeout. A 5 MB tool output scrubs in about 1.6 s.

## 1. Output scrubber (PostToolUse)

`scrub` reads the hook input from stdin and walks `tool_response`. It rewrites each string leaf and keeps every key, list and non-string value, so the replacement has the tool's own output shape for every tool: Bash, Read, Grep, WebFetch, MCP content arrays. It prints `hookSpecificOutput.updatedToolOutput` only when something changed.

Redacted to `[redacted:<kind>]`:

| Kind | Shape |
|---|---|
| `private-key` | `-----BEGIN ... PRIVATE KEY-----` through the END line, or to the end of the string when truncated. Covers PEM, OpenSSH, PGP blocks, raw or JSON-escaped (`\n`). |
| `age-key` | `AGE-SECRET-KEY-1...` |
| `github-token` | `ghp_ gho_ ghu_ ghs_ ghr_`, `github_pat_` |
| `anthropic-key` | `sk-ant-...` |
| `google-api-key` | `AIza...` |
| `cloudflare-token` | prefixed tokens, `cf<1-4 letters>_...` |
| `aws-access-key` | `AKIA` / `ASIA` + 16 |
| `jwt` | `eyJ...eyJ...sig` |
| `url-token` | value of `?token=`, `&token=`, `access_token=`, `auth_token=`, `api_token=`, `refresh_token=` in URLs; the key stays, so the Playwright connect URL reads `token=[redacted:url-token]` |
| `assignment` | `NAME=value`, `NAME: value`, `"NAME": "value"` and escaped `\"NAME\": \"value\"`, where NAME ends in `token`, `secret`, `key`, `password`, `passwd` or `pwd` (any case), and the value is 12+ characters, Shannon entropy at least 3.0 bits per character, not a path (`/`, `~`), not a reference (`$`, `<`, `[`, `{`), not a lowercase word list |

Values split across lines: a prefixed token may continue over a raw or escaped line break. The scrubber crosses a break only when the part before it is too short to be a whole token, so a token at a line end does not swallow the next line. When it crosses, it can also take the first word of the next line. That is over-redaction, the safe direction.

### Bash failures (PreToolUse `--wrap`)

PostToolUse fires only when a tool succeeds. A Bash command that exits non-zero fires `PostToolUseFailure`. Its input carries the output in an `error` string, and that event cannot replace anything (only `additionalContext`). Measured: without the wrapper, `printf <fake token>; exit 3` reaches the transcript in full.

`scrub --wrap` appends this line to every Bash command through PreToolUse `updatedInput`:

```
( exit $? ) || echo "[exit status $?]"
```

The command then always succeeds. The agent reads `[exit status N]` in place of an error, and the output goes through the scrubber. Deny rules still apply: Claude Code checks permission rules against the updated input and splits it into subcommands. The transcript keeps the command as Claude wrote it.

The wrapper does not help when the command never reaches its last line: `exit N`, `set -e` with a failing command, `exec`, or a timeout or interrupt. Those outputs still go through `PostToolUseFailure` unscrubbed. Non-Bash tool errors (an MCP error result, a failed WebFetch) are never scrubbed either.

### Fail-safe behaviour, measured on Claude Code 2.1.312

| Case | What happens | Source |
|---|---|---|
| Scrubber returns a valid replacement | The model, the transcript `tool_result`, `toolUseResult` and the hook attachment all hold the redacted text. The value appears 0 times in the `.jsonl`. | `e2e` guarded |
| Replacement does not match the tool's output shape (a string for Bash) | Claude Code **ignores it silently**: the attachment says `hook_success`, and the original value reaches the model and the transcript. No warning. | `e2e` malformed; docs: "a value that doesn't match the tool's output schema is ignored and the original output is used" |
| No hook | Value in the transcript | `e2e` unguarded |
| Bash exits non-zero, PostToolUse only | Value in the transcript | `e2e` post-only |
| Hook exits 1, times out, or prints invalid JSON | Original output is used; Claude Code records a non-blocking hook error | docs |
| `decision: "block"` | Does not redact; Claude still sees the original | docs |
| OpenTelemetry spans and analytics | Capture the original before hooks run | docs |

So the scrubber never builds a shape of its own. It returns the input structure with strings replaced, and it serializes the whole reply before it writes a byte. When it cannot scrub (unreadable input, or nesting deeper than about 15 000 levels), it prints nothing on stdout and exits 1 with `secret-guard: ... output NOT scrubbed`. The failure is visible as a hook error and is never a half-written reply.

### What the scrubber cannot do

- Unknown shapes pass: unprefixed legacy Cloudflare tokens, Grafana or Linode tokens, passwords outside a `name=value` form, values in base64, hex, gzip or URL encoding.
- `tool_input` is not touched. A secret Claude typed into a command is already in its own message.
- The tool has already run. A command that sent a value over the network has sent it.
- Hooks configured next to it see the original: all matching hooks of an event run in parallel on the same input (see Orca below).

## 2. Deny rules

`guard install` prints these under `permissions.deny`. Deny rules hold in `bypassPermissions` mode (measured: `e2e` denied runs in that mode, and both `Read .env` and `cat .env` were refused).

| Rule | Blocks |
|---|---|
| `Read(~/.config/sops/age/**)` | SOPS age key (`keys.txt`) |
| `Read(~/.config/**/token*)` | token files under `~/.config` at any depth |
| `Read(~/.config/gh/hosts.yml)`, `Read(~/.netrc)`, `Read(~/.git-credentials)`, `Read(~/.aws/credentials)`, `Read(~/.claude/.credentials.json)`, `Read(~/.codex/auth.json)` | well-known credential files |
| `Read(~/.password-store/**)` | password-store entries |
| `Read(~/.ssh/id_*)` | SSH private keys. Also blocks `id_*.pub`: a `!` carve-out cannot reach a `~/` rule |
| `Read(//**/.env)`, `Read(//**/.env.*)` | dotenv files anywhere. Also blocks `.env.example`, for the same reason. Not `.envrc` |
| `Read(//**/*.pem)`, `*.key`, `*.keystore`, `*.jks`, `*.p12` | key and keystore files anywhere, including public certificates in `.pem` |
| `Read(//proc/*/environ)` | another process's environment |
| `Bash(env)`, `Bash(printenv)`, `Bash(printenv *)`, `Bash(export -p)`, `Bash(declare -x)`, `Bash(set)` | environment dumps, also inside a pipeline (`env \| grep X`) |
| `Bash(sops -d *)`, `Bash(sops --decrypt *)`, `Bash(sops decrypt *)` | SOPS decryption to stdout. `sops exec-env` and `exec-file` are left open |
| `Bash(age -d *)`, `Bash(age --decrypt *)`, `Bash(gpg -d *)`, `Bash(gpg --decrypt *)` | decryption to stdout |
| `Bash(pass *)` | every `pass` call typed as a command, including `pass show`. Scripts that call `pass` internally, such as the playwright skill's `pw`, still work: a Bash rule matches only the command text Claude writes |
| `Bash(gh auth token*)` | printing the GitHub token |

What the permission system matches, from the permissions docs:

- `Read(path)` uses gitignore patterns. `~/` anchors at home, `//` at the filesystem root. A single leading `/` in user settings anchors at `~/.claude`, not at `/`. A bare name such as `.env` matches only under the current directory, which is why the rules above use `//**/`.
- A `Read` deny also blocks Grep and Glob (best effort), Edit and Write on the same path, `@file` mentions, the Bash file commands Claude Code recognizes (`cat`, `head`, `tail`, `sed`, `tee`), and `<` redirections. That is how the `Read` rules stop `cat ~/.config/sops/age/keys.txt`.
- A `Bash(...)` rule matches the command text after Claude Code splits `&&`, `||`, `;`, `|`, `&` and newlines, and strips `timeout`, `time`, `nice`, `nohup`, `stdbuf`, `command`, `builtin`, bare `xargs` and leading `VAR=value` assignments. A deny matches any subcommand, including one in `$(...)`, a subshell or a loop body. A trailing ` *` also matches the bare command.

What the rules cannot stop. The docs say a Bash rule "isn't a security boundary around the program":

- Another spelling: `/usr/bin/printenv`, `bash -c 'env'`, `sh -c 'sops -d f'`, `python3 -c 'import os; print(os.environ)'`, `git -C . ...`.
- Readers the rule cannot see: `grep -r . ~/.config`, `find -exec cat`, `cp key /tmp/x && cat /tmp/x`, `base64 < key` from a script, any interpreter that opens the file itself.
- `sops exec-env file 'printenv'`: exec-env is allowed on purpose, and the child can print what it received.
- MCP servers and hooks run outside the permission system.

The only path deny that holds against another command is the OS-level Bash sandbox (`sandbox.filesystem.denyRead`). It is off on this host, and it does not cover the file tools.

## 3. Environment scrub

### Claude Code: `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`

It strips credential-looking variables, by name or by value, from Bash, hook and stdio-MCP subprocesses. It keeps `GITHUB_TOKEN`, `GH_TOKEN`, `GH_ENTERPRISE_TOKEN`, `GITHUB_ENTERPRISE_TOKEN`, `HTTP(S)_PROXY` and `GIT_CONFIG_*`, and on Linux it runs Bash in its own PID namespace. Set it in the shell that starts `claude`, or in user settings `env`. Measured on 2.1.312:

- It **forces the permission mode to default**: `⚠ Permission mode forced to default — CLAUDE_CODE_SUBPROCESS_ENV_SCRUB is set (allowed_non_write_users hardening)`. Every bypass-mode worker would start prompting for each command. The workaround is an explicit `--allowedTools` list.
- From user settings or `--settings` it applies. From project `.claude/settings.json` it had no effect.
- In this host's environment it removed `CLAUDE_CODE_MESSAGING_TOKEN` and `XDG_RUNTIME_DIR`. `ps -e` saw 5 processes in place of about 550, so `ps`, `pgrep` and `kill` cannot reach host processes. A hook that needs a variable named like a credential, such as the Orca hook's `ORCA_AGENT_HOOK_TOKEN`, would likely lose it. Not tested inside Orca.
- In one run in default mode it left empty files in the working directory: `.env`, `.env.local`, `.env.development`, `.env.development.local`, `bunfig.toml`, `package.json`, lockfiles and `node_modules/`. They look like sandbox mount points.

Recommendation: not for bypass-mode workers today. Use it for interactive sessions only, and check the sessions listed above first. For a GitHub token, use `sandbox.credentials` `deny` instead: the scrub keeps that token on purpose.

### Codex: `[shell_environment_policy]`

In codex-rs `ignore_default_excludes` defaults to `true` (`unwrap_or(true)` in `config/src/shell_environment_policy.rs`), so variables named `*KEY*`, `*SECRET*` or `*TOKEN*` reach Codex subprocesses unless the operator sets:

```toml
[shell_environment_policy]
ignore_default_excludes = false
```

`inherit = "core"` is stricter. It passes only core variables such as `HOME`, `PATH` and `USER`, and a tool that needs more must list it under `set`. Neither setting is a credential boundary: the values are still readable from files and from `/proc`.

## 4. Orca forwarding

Orca's `~/.orca/agent-hooks/claude-hook.sh` is registered on PostToolUse and posts the full hook payload, `tool_response` included, to the local Orca endpoint. Hooks on one event run in parallel on the same input, so Orca receives the original output whether or not `scrub` is installed. A `updatedToolOutput` from one hook does not change what another hook reads.

To scrub before forwarding, the operator changes Orca's PostToolUse command (and PostToolUseFailure, which carries the output in `error`) from:

```
/home/<user>/.orca/agent-hooks/claude-hook.sh
```

to:

```
python3 $SKILL/scrub --payload | /home/<user>/.orca/agent-hooks/claude-hook.sh
```

`--payload` scrubs every string in the event, `error` included, and prints the whole event. On unreadable input it prints nothing, and the Orca script then exits without forwarding. Orca writes these settings entries itself and may restore them on update, so the durable fix belongs in Orca: run a configurable filter before the POST, or drop `tool_response` and `error` from the forwarded payload. The same applies to `codex-hook.sh`.

## 5. End-to-end harness

```
TMPDIR=<scratch dir> $SKILL/e2e
```

It makes one scratch git project per case, with fake values only. It writes `.claude/settings.json` there and runs `claude -p --setting-sources project --permission-mode bypassPermissions --model haiku`. User settings are not loaded, so the operator's hooks and rules do not interfere and are not touched. Then it greps the session's `.jsonl` under `$CLAUDE_CONFIG_DIR/projects` (default `~/.claude/projects`) for the fake value.

| Case | Settings | Expect |
|---|---|---|
| guarded | `guard install` hooks; Bash leak, Read of a file with a token, failing Bash, `guard doctor` | 0 occurrences, `[redacted:...]` present, doctor canary redacted |
| post-only | scrubber without the wrapper; failing Bash | value present |
| unguarded | none | value present |
| malformed | a hook that returns a string for Bash | value present (silent fail-open) |
| denied | `guard install` deny rules; Read and `cat` of `.env` | 0 occurrences |

It exits 0 when every case matches its expectation. The transcripts stay under `projects/` and hold fake values only.
