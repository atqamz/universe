---
name: github-labels
description: Use when listing, creating, editing, or deleting GitHub labels.
---

# github-labels

1. List first: `gh label list --limit 100`.
2. Reuse an existing label when it matches.
3. Create only when requested: `gh label create <name> --color <hex> --description <text>`.
4. Edit: `gh label edit <name> --new-name <new-name> --color <hex> --description <text>`.
5. Delete only with explicit authorization: `gh label delete <name> --yes`.
6. Do not create labels to avoid a conversation about naming.

Verify with `gh label list --search <name>`.
