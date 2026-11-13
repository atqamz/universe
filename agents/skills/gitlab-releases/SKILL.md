---
name: gitlab-releases
description: Use when creating, uploading to, or listing GitLab releases.
---

# gitlab-releases

1. Read the repository's release convention and existing tags first.
2. Create: `glab release create <tag> --name <name> --notes-file <file>`.
3. Create from a ref: `glab release create <tag> --ref <ref> --name <name> --notes-file <file>`.
4. Upload assets: `glab release upload <tag> <file>...`.
5. List: `glab release list`.
6. View: `glab release view <tag>`.
7. Never delete or move a published release without explicit authorization.

Verify with `glab release view <tag>`.
