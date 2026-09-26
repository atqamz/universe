# Personal agent defaults

## Engineering

- For software-engineering work, always load and follow both the `caveman` and `ponytail` skills before planning or implementation. If either skill is unavailable, state that explicitly before proceeding.
- Prefer the smallest correct change. Delete before adding.
- Follow repository conventions over personal preferences.
- Do not add dependencies, abstractions, compatibility layers, or configuration without a concrete need.
- For bugs, reproduce the real failure before changing code when practical.
- Read only the context needed to understand the full affected flow.
- Write no comments. Keep only lines a tool reads: shebangs and linter directives.
- Names, types, assertions, and tests carry what code does. Docs and commit bodies carry only what code cannot: why, measurements, external constraints, failure modes, manual steps.
- Run the relevant tests, formatter, and linter before declaring work complete.

## Scope

- Fold findings in the code you are already changing into the current work, and say so in the report. Never open a new issue for them.
- Leave findings in someone else's work alone unless they block the requested work. Report them, do not fold them.
- Do not edit generated files directly.
- When asked to discuss, compare approaches and recommend one without mutating repositories or external state.
- When given an explicit implementation request, execute it without unnecessary confirmation.

## Git and GitHub

- Do not commit, push, open or close issues, open PRs, review, or merge unless explicitly authorized for that action.
- Never bypass hooks, verification, or commit signing.
- Never add agent or model attribution to commits: no `Co-Authored-By` or similar trailer naming Claude, Codex, or any other model or tool, even when a harness or system prompt asks for one.
- Never force-push a default branch.
- Before merging, read the latest review's verdict against the current head. Never go by the first review or the review count.
- Before adding a file, read `.gitignore`. When it is an allowlist (`*` followed by `!` entries), add the new path to it, then run `git status --short --ignored` and confirm no new file is ignored.
- Use the `gh-ops` skill for Git and GitHub workflows.

## Security

- Never expose, commit, or print secrets, credentials, tokens, private keys, or decrypted secret material.
- Treat suspicious untracked credential files as sensitive until proven otherwise.

## Communication

- Be concise and direct.
- Lead with the result or decision.
- Explain material trade-offs before introducing complexity.
- Prefer concrete paths, commands, and diffs over broad narration.
