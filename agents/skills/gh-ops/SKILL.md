---
name: gh-ops
description: Use when creating or pushing branches and commits, opening or closing issues, opening or reviewing pull requests, merging, or running any gh CLI command.
---

# gh-ops

## Branches

Use trunk-based development. Branch from the default branch, keep branch names short, and merge promptly. Name issue branches `<issue-number>-<slug>` and other branches `<slug>`. Do not create an issue only to name a branch. Follow the upstream repository's convention when cloning an existing project.

## Commits

Keep each commit to one self-contained change. Use an imperative subject with a lowercase first word and no trailing period. Avoid planning terms such as phase, step, or milestone; state the actual change.

## Issues

- Write references as `owner/repo#N`, never only `#N`. Prefix non-closing relationships with `Related:` or `Depends on:`.
- Before asking questions, read the full issue body, comments, and linked pull requests. Do not repeat settled questions.
- Reuse existing labels. Add `--milestone` when appropriate, but do not create labels unless requested. Assign issues and pull requests to `atqamz`.
- Use one tracking issue for multi-part work. Close it only after every part lands.
- Comment on the issue after opening a pull request or landing work. Do not post "starting work" comments. Close with an outcome, for example `gh issue close N -c "done: ..."`.

## Pull requests

- Before creating or editing a pull request body or linking an issue, read the default branch's pull request template, including `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/`, or `docs/`, and read the existing body. Do not rewrite a body that already conforms. The repository template overrides this section; use the fallback below only when no template exists.
- Fallback body: `## Summary` with one to three bullets, a standalone issue reference, then `## Test plan`. Use `Closes owner/repo#N` only when merging that pull request into the default branch completes the entire issue. For partial work, follow the repository template or use `Related: owner/repo#N` when the template has no partial-work instruction.
- Treat "link this pull request to the issue" as ambiguous. `Related:` and `Depends on:` create timeline cross-references but never populate the pull request's Development box. The Development box requires a closing relationship through `Closes`, `Fixes`, `Resolves`, or GitHub's manual link, and merging into the default branch can then close the issue. If the user names or shows the Development box, create that closing relationship. Otherwise ask which relationship they mean before changing external state.
- In a stack, link every pull request to the tracking issue as the template requires and record direct pull request dependencies with `Depends on:`. Add one issue comment listing the full stack. By default, put a closing relationship only on the pull request whose merge completes the issue. If the user explicitly requests every stacked pull request in the Development box, link every requested pull request and do not merge any layer into the default branch before the issue is ready to close.
- After creating or editing a body, reread it with `gh pr view --json body,baseRefName,headRefName` and confirm the issue timeline contains the cross-reference. Command success alone is not verification.
- Keep each pull request self-contained. About 100 changed lines is healthy; 1,000 is usually too large. Include tests with the change. Separate refactors from features. Every layer of a stack must build when merged.
- Put `Closes`, `Fixes`, or `Resolves` directly before each issue reference. A plain reference links without closing. Closing keywords in commit messages can close issues without showing the pull request relationship, so put them in the body. They take effect only after merge into the default branch. Repeat the keyword for every issue; a comma-separated list closes only the first. Use full references across repositories. Verify closure after merge.

## Reviews

- Resolve every review before merging. Fix P1 and P2 findings in code, not only with thread replies. Reply to addressed comments through `gh api`, then resolve them. Request review again after pushing new code.
- Green CI is not enough. Do not merge with unresolved reviews.
- Ask when a request is unclear. When disagreeing, explain the reasoning and tradeoff and seek agreement.

## Merges

Use either `gh pr merge --merge` or `gh pr merge --squash`. Squash when intermediate commits are noisy. Never use `--rebase`.

Do not merge stacked pull requests with `gh pr merge`. Use `gh stack merge <PR> --yes --squash` to merge the stack bottom-up as one operation. Let GitHub retarget bases; do not rebase each layer and wait for checks again. Create a stack with `gh pr create --base <branch>`. GitHub assigns separate numbers, so gaps between pull request and issue numbers are normal. Check out a stack created in another session with `gh stack checkout <PR>`.

When rebasing after a base changes, skip commit-and-revert pairs that cancel each other. Do not resolve their conflicts: replaying the revert can erase the new base's changes to those files. Verify the final delta with `git diff --stat <base>..HEAD`.

After every merge, run `gh issue view N --repo owner/repo --json state -q .state`. If the issue remains open, close it with `gh issue close N -c "landed in #PR"`. Delete both local and remote branches. Never trust automatic closure without verification.
