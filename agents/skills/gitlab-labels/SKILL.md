---
name: gitlab-labels
description: Use when listing, creating, or deleting GitLab labels.
---

# gitlab-labels

1. List first: `glab label list`.
2. Reuse an existing label when it matches.
3. Create only when requested: `glab label create --name <name> --color <hex> --description <text>`.
4. Delete only with explicit authorization: `glab label delete <name>`.
5. Do not create labels to avoid a conversation about naming.

Verify with `glab label list`.
