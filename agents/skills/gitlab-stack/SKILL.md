---
name: gitlab-stack
description: Use when creating, syncing, reordering, or landing a GitLab stacked-diff series with glab stack.
---

# gitlab-stack

`glab stack` is experimental. Confirm the installed `glab` supports the subcommand before relying on it.

1. Check out the base branch and push it: `git switch <base>` then `git push <remote> <base>`.
2. Create the stack: `glab stack create <name>`.
3. Add a diff: `glab stack save -m "<description>"`.
4. Update the current diff: `glab stack amend`.
5. List diffs: `glab stack list`.
6. Navigate: `glab stack move`, `glab stack switch`, `glab stack first`, `glab stack last`, `glab stack next`, `glab stack prev`.
7. Reorder: `glab stack reorder`.
8. Push and create or update merge requests: `glab stack sync`.
9. Rebase onto the latest base: `glab stack sync --update-base`.
10. Delete the stack: `glab stack delete`.
11. Merge bottom-up with `glab mr merge` for each merge request. `glab stack` has no stack merge command.
12. Link every merge request to the tracking issue and record dependencies with `Depends on:`.

Verify with `glab stack list` and `glab mr list`.
