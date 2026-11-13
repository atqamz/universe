---
name: github-comment
description: Use when commenting on GitHub issues or pull requests, or replying to review threads.
---

# github-comment

1. Read the full thread before commenting.
2. Do not post "starting work" comments.
3. Comment after opening a pull request or landing work.
4. State the result, the evidence, and any blocker. Keep it short.
5. Issue comment: `gh issue comment <N> --body <text>`.
6. Pull request comment: `gh pr comment <N> --body <text>`.
7. Reply to a review comment in its thread: `gh api repos/<owner>/<repo>/pulls/<N>/comments/<comment-id>/replies -f body=<text>`.
8. Resolve the thread only after the change is pushed or the answer is posted: `gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<thread-id>"}) { thread { isResolved } } }'`.
9. Close an issue with an outcome, not a status update: `gh issue close <N> -c "done: ..."`.

Verify the comment URL is present in `gh issue view <N> --comments` or `gh pr view <N> --comments`.
