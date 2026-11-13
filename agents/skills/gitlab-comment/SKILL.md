---
name: gitlab-comment
description: Use when commenting on GitLab issues or merge requests, or replying to discussions.
---

# gitlab-comment

1. Read the full thread before commenting.
2. Do not post "starting work" comments.
3. Comment after opening a merge request or landing work.
4. State the result, the evidence, and any blocker. Keep it short.
5. Issue comment: `glab issue note <N> -m <text>`.
6. Merge request comment: `glab mr note create <N> -m <text>`.
7. Reply in a discussion: `glab mr note create <N> --reply <discussion-id> -m <text>`.
8. Resolve a discussion after the change is pushed or the answer is posted: `glab mr note resolve <N> <discussion-id>`.
9. Close an issue with an outcome: post the note first, then `glab issue close <N>`.

Verify with `glab issue view <N>` or `glab mr view <N>`.
