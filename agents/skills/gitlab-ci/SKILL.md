---
name: gitlab-ci
description: Use when inspecting, retrying, or cancelling GitLab CI pipelines or jobs.
---

# gitlab-ci

1. Show the current pipeline: `glab ci status`.
2. View a pipeline: `glab ci view <pipeline-id>`.
3. List recent pipelines: `glab ci list`.
4. Read a failed job: `glab ci trace <job-id>`.
5. Read the failure before retrying. Do not retry a deterministic failure.
6. Retry: `glab ci retry <job-id>`.
7. Cancel: `glab ci cancel <job-id>`.
8. Validate configuration: `glab ci lint`.

Verify with `glab ci status`.
