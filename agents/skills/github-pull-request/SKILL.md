---
name: github-pull-request
description: Use when creating, editing, reviewing, or merging a GitHub pull request.
---

# github-pull-request

## Create or edit

1. Read the default branch's template: `.github/PULL_REQUEST_TEMPLATE/`, `.github/pull_request_template.md`, or `docs/`.
2. Read the existing body before editing. Do not rewrite a body that already conforms.
3. Use the template. Without one, write `## Summary` with one to three bullets, a standalone issue reference, then `## Test plan`.
4. Put `Closes`, `Fixes`, or `Resolves` directly before each issue reference. Use `Related:` or `Depends on:` for partial work.
5. Treat "link this pull request to the issue" as ambiguous. `Related:` and `Depends on:` do not populate the Development box. Ask before creating a closing relationship unless the user named the Development box.
6. Keep the pull request self-contained. About 100 changed lines is healthy; 1,000 is usually too large.
7. Include tests with the change. Separate refactors from features.
8. Create: `gh pr create --base <base> --head <head> --title <title> --body-file <file>`.
9. Edit: `gh pr edit <N> --title <title> --body-file <file>`.
10. Verify: `gh pr view <N> --json body,baseRefName,headRefName` and confirm the issue timeline contains the cross-reference.

## Review

1. Resolve every review before merging.
2. Fix P1 and P2 findings in code, not only with thread replies.
3. Reply to addressed comments through `gh api`, then resolve them.
4. Request review again after pushing new code: `gh pr edit <N> --add-reviewer <user>`.
5. Green CI is not enough. Do not merge with unresolved reviews.
6. Ask when a request is unclear. Explain the reasoning and tradeoff when disagreeing.

## Merge

1. Read the latest review verdict against the current head. Never go by the first review or the review count.
2. Merge: `gh pr merge <N> --merge` or `gh pr merge <N> --squash`. Never use `--rebase`.
3. Squash when intermediate commits are noisy.
4. After merge, run `gh issue view <N> --repo <owner/repo> --json state -q .state`.
5. If the issue remains open, close it: `gh issue close <N> -c "landed in #<PR>"`.
6. Delete the local and remote branches.
7. Verify closure and branch deletion.
8. For stacks, use `github-pull-request-stack`.
