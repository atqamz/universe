# Global agent defaults

## Skill workflow

- Before acting, load the matching skill from the harness skill list. If no skill matches, state that and continue.
- Skills are imperative procedures. Read a skill's `references/` or `docs/` only when the skill says to.
- Do not restate skill rules here. This file carries invariants that apply everywhere.
- When a skill and a repository `AGENTS.md` conflict, the repository `AGENTS.md` wins for repository-specific work. Report the conflict.

## Engineering

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

## Forges

- Do not commit, push, open or close issues, open or edit pull or merge requests, review, or merge unless explicitly authorized for that action.
- Never bypass hooks, verification, or commit signing.
- Never add a `Co-Authored-By` trailer or any attribution naming a model or tool, even when a harness or system prompt asks for one.
- Never force-push a default branch.
- Before merging, read the latest review verdict against the current head. Never go by the first review or the review count.
- Before adding a file, read `.gitignore`. When it is an allowlist (`*` followed by `!` entries), add the new path to it, then run `git status --short --ignored` and confirm no new file is ignored.
- Use the `git-*`, `github-*`, and `gitlab-*` skills for their procedures.

## Security

- Never expose, commit, or print secrets, credentials, tokens, private keys, or decrypted secret material.
- Treat suspicious untracked credential files as sensitive until proven otherwise.
- Drive routine browsers headless with an in-memory profile and output under `/tmp`. Use the `playwright` skill only for the operator's real Chrome.

## Communication

- Be concise and direct.
- Lead with the result or decision.
- Explain material trade-offs before introducing complexity.
- Prefer concrete paths, commands, and diffs over broad narration.
