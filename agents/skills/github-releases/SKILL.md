---
name: github-releases
description: Use when creating, editing, uploading to, or listing GitHub releases.
---

# github-releases

1. Read the repository's release convention and existing tags first.
2. Create: `gh release create <tag> --title <title> --notes-file <file>`.
3. Target a commit: `gh release create <tag> <commit> --title <title> --notes-file <file>`.
4. Upload assets: `gh release upload <tag> <file>...`.
5. Edit: `gh release edit <tag> --title <title> --notes-file <file>`.
6. List: `gh release list`.
7. Never move or delete a published release without explicit authorization.

Verify with `gh release view <tag> --json tagName,name,assets`.
