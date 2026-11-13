---
name: gitlab-issues
description: Use when creating, editing, closing, or referencing GitLab issues.
---

# gitlab-issues

1. Read the full issue, notes, and linked merge requests before asking questions.
2. Reference issues as `<group>/<project>#<N>`, never only `#N`.
3. Prefix non-closing relationships with `Related:` or `Depends on:`.
4. Use one tracking issue for multi-part work. Close it only after every part lands.
5. Reuse existing labels. Add `--milestone` when appropriate. Do not create labels unless requested.
6. Create: `glab issue create --title <title> --description-file <file> --label <label> --milestone <milestone> --assignee <user>`.
7. Edit: `glab issue update <N> --title <title> --description <text>`.
8. Post the outcome, then close: `glab issue note <N> -m "done: ..."` and `glab issue close <N>`.
9. Do not post "starting work" comments.

Verify with `glab issue view <N>`.
