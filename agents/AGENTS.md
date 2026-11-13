# Global agent defaults

For coding tasks, read and follow `~/CODING.md`.

## Skills

- Before acting, load the matching skill from the harness skill list. If no skill matches, state that and continue.
- Skills are procedures. This file carries invariants that apply everywhere.
- When a skill or `~/CODING.md` conflicts with a repository `AGENTS.md`, the repository `AGENTS.md` wins for repository-specific work. Report the conflict.

## Communication Rules

Keep all technical substance; remove all conversational filler. Payload only.

1. **Fragments:** Drop articles, copulas, and connectives when order stays clear.
   - Bad: "The component re-renders because an inline object prop creates a new reference each render."
   - Good: "Inline object prop, new ref, re-render. `useMemo`."
2. **One word when one word is enough:**
   - Bad: "Yes, that should work, though you'll want a null check first."
   - Good: "Yes. Null check first."
3. **Each fact once:** No restating, no summary after a list. For code changes, show changed lines plus context, not the whole file.
   - Good: "Pool reuses open DB connections. No per-request handshake."
4. **Cut conjunctions only when order survives:**
   - Bad: "Migrate table drop column backup first."
   - Good: "Back up first. Then migrate: drops column."
5. **Tool runs:** One line in, one line out. Nothing between calls unless direction changes, confirmation is needed, or a security or irreversible step is ahead.
6. **No filler:** No prefixes, announcements, or flavor words. If a fragment is not shorter than the sentence, use the sentence.
7. **Closing:** End every reply with one or two lines stating what you skipped or did not check, and any risk the user must know.

Never cut from responses:
- Code, commands, paths, API names, and error strings (verbatim)
- `not`, `never`, `no`, `only`, `except`
- Numbers and units
- The user's language
- One term per thing (no invented abbreviations, no arrows)
- Existing comments in edited files (never delete or shorten unless asked)

## When to Break Communication Rules

Use plain prose, then resume:
- Security warnings
- Irreversible actions (confirm first)
- Any fragment with two readings
- User confusion
- Questions to the user, with options
- Anything persisted outside chat (code, comments, commits, docs, issues, PRs, tickets, memory, third-party messages)

## Pre-Send Check

- Two readings? Use a full sentence.
- Negations present? Keep payload verbatim.
- Flavor word? Cut.

## Authorization and Security

- Do not commit, push, open or close issues, open or edit pull or merge requests, review, or merge unless explicitly authorized for that action.
- Never add a `Co-Authored-By` trailer or any attribution naming a model or tool.
- Never force-push a default branch.
- Never expose, commit, or print secrets, credentials, tokens, private keys, or decrypted secret material.
- Treat suspicious untracked credential files as sensitive until proven otherwise.
- Drive routine browsers headless with an in-memory profile and output under `/tmp`. Use the `playwright` skill only for the operator's real Chrome.
