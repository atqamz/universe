# 0016. qmd MCP search is collection-scoped

## Context

One qmd index holds every documentation corpus this workstation owns, and the collection names carry the profile: `atqamz-*`, `yes2games-*`, `hage-*`.
`0015-one-owner-ai-harness-integration.md` registers that one index into all three harnesses.

In qmd 2.5.3 a collection participates in unscoped search unless it is marked `includeByDefault = false`, and the MCP `query` tool treats its `collections` argument as optional: when the argument is absent it substitutes every default collection.
So the failure mode is silent and available by default.
An agent working in a `yes2games` repository that calls `query` without naming a collection retrieves `atqamz` and `hage` documentation in the same result set, and nothing in the transcript says that happened.

Marking collections `includeByDefault = false` does not fix it.
That flag turns the fallback into an empty list, `store.search` then receives `undefined`, and the search widens to everything again.
Instructing the model to always pass `collections` does not fix it either: a prompt rule is not a boundary, and the pinned release's own MCP instructions tell the model to scope with a singular `collection` parameter that the schema does not have.

## Decision

The boundary is enforced in the package, not in a prompt.
`modules/home/qmd-mcp-require-explicit-collections.patch` is a downstream patch applied to the pinned upstream v2.5.3 flake package: `collections` becomes a required `z.array(z.string()).min(1)`, and the `collections ?? defaultCollectionNames` fallback is deleted, so an omitted or empty argument is an MCP validation error before any search runs.
The optional HTTP transport's REST search endpoint gets the same requirement, because it is the same bypass in the same binary.
The patch also corrects the instruction text to the plural parameter the schema actually exposes.

CLI qmd is unchanged. `qmd search` stays unscoped, because the human running it chose the scope by typing the command.

`dotagents/AGENTS.md` carries the matching routing rule - scope to the current repository's profile, never mix profiles unless asked - so the agent knows which collection to name rather than merely being refused.

## Consequence

Cross-profile retrieval is now something the caller has to ask for by name.
There is no configuration, and no agent instruction, that re-enables an unscoped agent-facing search.

The cost is a patch that must be re-checked on every qmd bump: if upstream renames the parameter or restructures `registerTool`, the patch stops applying and the package fails to build.
That is the intended failure direction, since the alternative is silently losing the isolation.
Upstream adopting a required scope, or a per-collection isolation setting that survives the fallback, is what retires this patch.

Splitting the corpus into three indexes with three MCP servers was rejected.
It triples the model payload, the timers, and the doctor surface to express a constraint that is one argument on one tool.
