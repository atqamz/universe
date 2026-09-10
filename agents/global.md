# Personal agent defaults

## Engineering

- Prefer the smallest correct change. Delete before adding.
- Follow repository conventions over personal preferences.
- Do not add dependencies, abstractions, compatibility layers, or configuration without a concrete need.
- For bugs, reproduce the real failure before changing code when practical.
- Read only the context needed to understand the full affected flow.
- Comments explain non-obvious why, not what the next line already says.
- Run the relevant tests, formatter, and linter before declaring work complete.

## Scope

- Do not modify unrelated findings unless they block the requested work. Report them separately when material.
- Do not edit generated files directly.
- When asked to discuss, compare approaches and recommend one without mutating repositories or external state.
- When given an explicit implementation request, execute it without unnecessary confirmation.

## Git and GitHub

- Do not commit, push, open or close issues, open PRs, review, or merge unless explicitly authorized for that action.
- Never bypass hooks, verification, or commit signing.
- Never force-push a default branch.
- Use the `gh-ops` skill for Git and GitHub workflows.

## Security

- Never expose, commit, or print secrets, credentials, tokens, private keys, or decrypted secret material.
- Treat suspicious untracked credential files as sensitive until proven otherwise.

## Communication

- Be concise and direct.
- Lead with the result or decision.
- Explain material trade-offs before introducing complexity.
- Prefer concrete paths, commands, and diffs over broad narration.
