---
name: playwright
description: Use when a task needs the operator's real Chrome through the Playwright CLI and extension: dashboards, consoles, uploads, anything behind an operator login. Run the preflight first.
---

# playwright

Drive the operator's running Chrome through `@playwright/cli` and its extension. Files live next to this skill; below, `$SKILL` is this directory.

## 1. Preflight (always first)

```
$SKILL/preflight
```

Takes seconds, never longer than about 25 s. Checks `npx`, the `pass` entry, a running Chrome, and a real attach and detach. On failure it prints one line naming what the operator must do and exits 1. Report `stuck` with that line at once. Do not retry in a loop and do not wait for an approval click.

## 2. Call the CLI through `$SKILL/pw`

`pw` takes the same arguments as `playwright-cli`, injects the token from `pass`, picks the Chrome profile, and pipes all output through `sed 's/token=[^&]*/token=<redacted>/'`. Every command can print the connect tab URL in its "Open tabs" list, so never call `npx @playwright/cli` directly. Never print, paste or log that URL or the token.

| Profile | `PW_PROFILE` | pass entry | Use |
|---|---|---|---|
| yes2games (Chrome `Default`) | `y2g` (default) | `playwright/token-y2g` | All fleet work: Play Console, GCP, dashboards |
| personal (Chrome `Profile 1`) | `personal` | `playwright/token-personal` | Only when the task names the personal profile |

Equivalent raw attach, redaction added:

```
PLAYWRIGHT_MCP_PROFILE_DIR_NAME=Default PLAYWRIGHT_MCP_EXTENSION_TOKEN="$(pass show playwright/token-y2g)" npx -y @playwright/cli@latest -s=<name> attach --extension=chrome 2>&1 | sed 's/token=[^&]*/token=<redacted>/'
```

`PLAYWRIGHT_MCP_PROFILE_DIR_NAME` is needed because attach otherwise opens Chrome's last-used profile, which fails with "did not connect within 30s" when that is the other profile. `pw` sets it.

## 3. Session etiquette

- Use a fresh `-s=<name>` per task and per retry.
- Attach lands on the operator's active tab. Open your own: `pw -s=<name> tab-new URL`. Leave the operator's tabs alone, including the Hand board.
- When done: `pw -s=<name> tab-close N`, then `pw -s=<name> detach`. Delete the `.playwright-cli/` folder the CLI writes in the working directory. Do not commit it.
- Never run `request N`: it prints request headers with the session auth. Use `requests` then `--raw response-body N`.
- The CLI's tab may be hidden, so `click` and `drop` can time out on "stable". Use `eval` with `el.click()` inside `setTimeout`.

## 4. Large file upload

`upload <file>` can fail with `DOM.setFileInputFiles ... Not allowed` and leave a file chooser that blocks every command. `drop --path` can hang on a hidden tab. An in-page fetch to a 127.0.0.1 server never arrives. The route below worked for 145 MB and 903 MB files:

1. `split -b 16M file part-` in a scratch directory.
2. One `run-code --filename script.js`: `page.route(/\/__up\/partNN$/, r => r.fulfill({path}))` for each part, then in-page `fetch` of each part, sha256 per part with `crypto.subtle`, assemble a `File`, keep it on `window`.
3. Compare per-part checksums with `sha256sum` on the parts.
4. Call `page.unrouteAll()` before submit. The CLI's `unroute` does not see run-code routes. A live route during the PUT kills the extension session and loses the upload.
5. `eval`: set `input[type=file].files` through `DataTransfer`, dispatch `change`, set text fields through the native value setter plus an `input` event, then click submit inside `setTimeout`.

## 5. Do not use it for

- Passwords, 2FA codes, recovery codes, key material: never typed. The operator logs in.
- Submitting console changes without explicit permission in the brief.
- Work that an API, `gh` or a headless browser covers.

## 6. When blocked

Report `stuck` with: the preflight line verbatim, the profile, the session name, and what you had finished. Never include the token or the connect tab URL. Typical operator actions: start Chrome (agent shells have no display; the operator or `WAYLAND_DISPLAY=wayland-1 DISPLAY=:0 setsid nohup google-chrome-stable --profile-directory=Default &` then wait about 15 s), enable the Playwright extension, fix the pass entry, log in.
