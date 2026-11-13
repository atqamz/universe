---
name: git-tags
description: Use when creating, listing, pushing, or deleting Git tags.
---

# git-tags

1. Read the repository's release convention and existing tags first: `git tag --list`.
2. Create an annotated tag: `git tag -a <tag> -m <message>`.
3. Sign when the repository requires it: `git tag -s <tag> -m <message>`.
4. Push one tag: `git push <remote> <tag>`.
5. Push all tags: `git push <remote> --tags`.
6. Delete a local tag: `git tag -d <tag>`.
7. Delete a remote tag: `git push <remote> --delete <tag>`.
8. Never move or force-update a published tag without explicit authorization.

Verify with `git show <tag>` and `git ls-remote --tags <remote> <tag>`.
