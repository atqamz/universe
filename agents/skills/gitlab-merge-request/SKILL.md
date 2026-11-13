---
name: gitlab-merge-request
description: Use when creating, editing, reviewing, or merging a GitLab merge request.
---

# gitlab-merge-request

## Create or edit

1. Read `.gitlab/merge_request_templates/` and the existing description before editing.
2. Use the template. Without one, write `## Summary` with one to three bullets, an issue reference, then `## Test plan`.
3. Put `Closes #<N>` in the description only when merging closes the whole issue. Use `Related: #<N>` or `Depends on: #<N>` for partial work.
4. Keep the merge request self-contained. Include tests with the change. Separate refactors from features.
5. Create: `glab mr create --title <title> --description-file <file> --target-branch <base> --source-branch <branch> --remove-source-branch --squash-before-merge`.
6. Link an issue: `glab mr create --related-issue <N> --title <title> --description-file <file>`.
7. Edit: `glab mr update <N> --title <title> --description <text>`.
8. Verify with `glab mr view <N>` and confirm the issue shows the merge request.

## Review

1. Read the latest approvals and discussions before merging.
2. Approve with the reviewed head: `glab mr approve <N> --sha <sha>`.
3. Resolve every discussion before merging.
4. Reply in the thread: `glab mr note create <N> --reply <discussion-id> -m <text>`.
5. Resolve the thread after the change is pushed: `glab mr note resolve <N> <discussion-id>`.
6. Re-request review after pushing new code: `glab mr update <N> --reviewer <user>`.
7. Do not merge with unresolved discussions or failing required pipelines.

## Merge

1. Read the latest review verdict against the current head. Never go by the first approval or the approval count.
2. Merge: `glab mr merge <N> --yes --squash --remove-source-branch --sha <sha>`.
3. Use `--auto-merge=false` only when the pipeline has already passed and the merge must happen immediately.
4. Do not use `--rebase` unless the user requests it.
5. After merge, run `glab issue view <N>`.
6. If the issue remains open, close it: `glab issue close <N>`.
7. Verify the issue state and that the source branch is gone.
8. For stacks, use `gitlab-stack`.
