# Global Context

Defaults. Project CLAUDE.md overrides.

@context/GIT.md
@context/GITHUB.md
@context/CODING.md
@context/COMMUNICATION.md
@context/SECURITY.md
@context/CONTEXT.md
@context/MEMORY.md
@context/GRAPHIFY.md

# Cross-project map

Auto-generated daily by graphify-sync (machine-local, not version-controlled).
Lists sibling projects + folder paths so cross-project references resolve
without re-discovery each session.

@PROJECTS.md

# Brain — canonical memory

`~/brain` is the cross-session, cross-machine memory store (git source of truth,
auto-pulled by home-manager). When a prompt might be answered from past work — a
decision, an outcome, a non-obvious learning, regardless of current directory —
consult the brain before answering:

1. Read `~/brain/index.md` (thin catalogue).
2. Open only the `~/brain/notes/<slug>.md` whose hook matches. Cite it.

`notes/` is canon (trust it). `log/` is append-only provenance (verify, do not cite blindly).
Do not bulk-read the brain; index first, then the one matching note.
