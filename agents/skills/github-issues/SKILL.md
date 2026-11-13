---
name: github-issues
description: Use when creating, editing, closing, or referencing GitHub issues.
---

# github-issues

1. Read the full issue body, comments, and linked pull requests before asking questions.
2. Reference issues as `owner/repo#N`, never only `#N`.
3. Prefix non-closing relationships with `Related:` or `Depends on:`.
4. Use one tracking issue for multi-part work. Close it only after every part lands.
5. Reuse existing labels. Add `--milestone` when appropriate. Do not create labels unless requested.
6. Assign issues to `atqamz`.
7. Create: `gh issue create --title <title> --body-file <file>`.
8. Edit: `gh issue edit <N> --title <title> --body-file <file>`.
9. Close with an outcome: `gh issue close <N> -c "done: ..."`.
10. Do not post "starting work" comments.

Verify with `gh issue view <N> --json state,labels,assignees`.
