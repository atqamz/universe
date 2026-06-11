# persistent LLM memory design (issue #12)

Give Claude a single canonical memory so it remembers work across sessions,
folders, and devices. This supersedes and retires the current per-project
auto-memory (`~/.claude/projects/*/memory/`) and graphify. The brain becomes the
one canonical store.

## Goal

Claude should not forget. Work done in folder A today, a note left in folder C
that applies generally, a decision locked last week — all of it should resurface
when relevant, regardless of the current working directory. Free, private, git
as source of truth, retrieval local (no paid embedding API, no Claude usage burnt
on search).

## Diagnosis (why the current setup is replaced)

The existing auto-memory + graphify is retired because the felt pain is **E:
not auto-updating, too much manual intervention**. Recall also misfires
intermittently (facts present but not pulled), content quality drifts (junk
saved, important things missed), and graphify's output never visibly lands in
answers. The root cause is the **write/maintenance loop**, not retrieval. The
design therefore leads with automatic capture and treats retrieval as a
supporting (but still wanted) concern.

This is a deliberate inversion of an earlier qmd-first sketch, which optimised
the retrieval engine (the heaviest, most NixOS-risky part) while leaving capture
manual.

## Scope

In scope: **memory** — Claude remembering its own work and the user's notes.

Out of scope: a knowledge base over external sources (dumping articles /
transcripts into a `raw/` tree for the LLM to digest). That is a different
project; if wanted, it gets its own spec later. No `raw/`, no article ingest
here.

## Architecture

Two repos, two roles; declarative integration in `universe`.

```
dotai/   (stable, rarely commits)          brain/   (churns, auto-commits per session)
└── claude/                                ├── log/      session digests, append-only,
    ├── CLAUDE.md      brain awareness      │            auto-written by Stop hook, provenance
    ├── context/       always-carried       ├── notes/    canon, promoted from log/
    ├── settings.json  hooks + qmd MCP       ├── index.md  thin catalogue of notes/
    └── bin/brain-recall                     └── CLAUDE.md conventions + workflow
         |                                        |
         | HM mkOutOfStoreSymlink                 | HM systemd user service
         v                                        v
    ~/.claude/{CLAUDE.md,context,            ~/brain  (clone; auto-pull, deliberate-push)
     settings.json,bin/brain-recall}
```

### Two tiers of memory

- **Always-carried** — `dotai` → `~/.claude/CLAUDE.md` + `context/`. Loaded every
  session unconditionally. The fixed operating rules.
- **Recalled-when-relevant** — `brain/notes/`. Pulled in only when the agent
  judges it relevant to the prompt, regardless of working directory.

### Why two repos

`dotai` is stable (hand-tuned config, infrequent commits); `brain` churns (the
Stop hook commits a digest every session). Splitting keeps the config history
readable instead of drowned in auto-write commits, and gives each a clean
lifecycle. Cost: two clones / two sync paths on a new machine — acceptable for a
solo user.

## Write path — automatic capture (the cure for E)

A **global Stop hook** (declared in `dotai`'s `~/.claude/settings.json`) fires
when any Claude Code session ends, in any directory. It runs headless
`claude -p` to extract a session digest and append it to `brain/log/`, then
commits and pushes.

- **Append-only, never canon.** Each session writes a new, uniquely named file
  under `log/` (e.g. timestamp + session id). Append-only means concurrent
  devices never conflict, and hallucination is contained to `log/` — it cannot
  corrupt the `notes/` the user reads.
- **Provenance stamped.** Every digest records its source (session id, cwd, the
  files/commits touched) so later promotion and linting can verify against
  reality. Unsourced claims are deletion candidates.
- **Extraction discipline.** The digest prompt records only decisions, outcomes,
  and non-obvious learnings grounded in the actual session — not speculation.
- **Direct to `main`.** Because `log/` is append-only and low-stakes, the hook
  pushes straight to `main`; no review gate on capture.

Token cost and latency at session end are accepted (the user chose automatic
capture knowing this). A substantiality gate (skip trivial sessions) is a
plan-level refinement, not a design blocker.

## Read path — on-demand retrieval

**Not** a per-prompt `UserPromptSubmit` hook — that taxes every prompt with
latency (a resident qmd daemon) and pollutes context with snippets on trivial
prompts. Instead:

- **qmd MCP** registered globally in `~/.claude/settings.json` → tools
  `query` / `get` / `multi_get` / `status` available in every session, any cwd.
- **Standing instruction** in `~/.claude/CLAUDE.md`: when a prompt might be
  answered from the brain, query it (qmd) before answering; read `index.md`
  first at small scale. The agent recalls when it judges relevant; context stays
  clean. Recall runs through **qmd** (the MCP tools below) or the thin
  `bin/brain-recall` CLI; both read `index.md` + `notes/`. `brain-recall` is the
  shell entry point — it queries qmd when available and falls back to grep over
  `index.md`/`notes/` when not, so recall works the same whether or not qmd built.

### qmd — in scope

qmd (`@tobilu/qmd`, MIT, Node ≥ 22) does local hybrid retrieval (BM25 via FTS5 +
vector via sqlite-vec + local-GGUF LLM rerank), with stdio / HTTP / daemon MCP
modes. Index and ~2GB GGUF models live in `~/.cache/qmd/` (machine-local, never
committed, rebuilt per machine). qmd is registered as a global MCP server in
`settings.json` (tools `query` / `get` / `multi_get` / `status`) and is the
retrieval engine for the brain.

**A NixOS validation spike comes first** — confirm `qmd embed` + `qmd query`
actually run on the target host before wiring dependents — because the native deps
(`better-sqlite3`, `node-llama-cpp`) are exactly the kind that break on NixOS, and
there is no documented NixOS support. The spike is a build task, not a deferral:
qmd ships in this work. If the spike exposes a packaging gap, `brain-recall` and
the agent fall back to grep over `index.md`/`notes/` so recall still functions
(graceful degradation), and the packaging gap is fixed rather than the feature
dropped.

Spec corrections to carry: there is no `qmd update --pull` flag — pull is a
per-collection `update-cmd` (set to `git pull`) that `qmd update` runs first. The
CLI command is `qmd multi-get` (hyphen) though the MCP tool is `multi_get`.

## Canon gate — promotion via scheduled PR

> **Deferred to a follow-up plan.** The automated promotion timer is built after
> the rest ships — it needs `log/` populated by the Stop hook to have anything to
> promote, and the gate works manually meanwhile (the user opens a `log/`→`notes/`
> PR by hand, or edits `notes/` directly). Everything else in this design is in
> scope now.

Promotion `log/` → `notes/` is where hallucination/noise is filtered, and it is
the single human control point.

- A **local systemd user timer** (the `graphify-sync` pattern: runs `claude -p`
  on the Claude Code subscription, no API key, no paid Action) runs a **lint
  agent** periodically. The agent reads `log/`, verifies claims against their
  provenance, dedups against existing `notes/` (via qmd or index), flags
  contradictions and stale claims, and drafts promotions.
- The agent creates a branch, pushes, and opens a **PR on the `brain` repo via
  `gh`**. The user reviews the PR on GitHub (including from a phone) and merges to
  promote. Async, mergeable anytime.
- Why a local timer rather than a GitHub Action: the LLM work runs on the
  subscription locally for free; GitHub is only the review surface. An Action
  would need a paid API key.

Layered mitigation, independent of the gate: strict extraction prompt
(grounded + dedup-checked + no speculation), mandatory provenance, and the
periodic lint pass that proposes deletions to keep entropy down.

## NixOS / home-manager integration (in `universe`)

No stow anywhere.

- **`dotai` → `~/.claude`** via home-manager `mkOutOfStoreSymlink`: the symlink is
  declared in the flake (reproducible) but points at the live repo checkout, so
  editing `CLAUDE.md` / `context/` is instantly live with **no rebuild**. This
  beats `home.file` (which forces a rebuild per edit) and stow (not captured in
  the flake). Files linked: `CLAUDE.md`, `context/`, `settings.json`,
  `bin/brain-recall` (plus the hook/statusline scripts settings.json references).
- **Volatile `~/.claude`** — `projects/`, auth tokens, history — stays
  machine-local and untracked. Home-manager does not touch it. No secrets enter
  any repo.
- **`brain` sync** — a home-manager systemd **user** service/timer (mirroring the
  issue #4 secrets-sync pattern): auto-pull `~/brain` (`git pull --ff-only`,
  skip + notify on divergence, never clobber); push is deliberate (the Stop hook
  pushes `log/`; promotion pushes via PR).
- **`dotfiles` stays AI-free** — all AI config moves out into `dotai`. Repo
  strategy: the old `dotfiles` stays for sfx14 (not edited in place); universe-era
  non-AI dotfiles get a new `dotfiles-universe` repo, AI config gets `dotai`; once
  fully migrated, the old `dotfiles` is deleted and `dotfiles-universe` renamed to
  `dotfiles`.

## Retirement / migration (the "fusion")

- **graphify** — pensioned: stop the `graphify-sync` user timer, drop the
  `graphify-personal` / `graphify-memory` MCP servers from config. (The
  graphify-sync *mechanism* — a local timer running `claude -p` on the
  subscription — is reused for the promotion PR job.)
- **auto-memory** (`~/.claude/projects/*/memory/`) — its existing facts are
  migrated into `brain/notes/`, then the per-project memory is abandoned. `brain`
  becomes the sole canonical store.

## Data flow

- **New machine:** clone `dotai` + `brain`; home-manager symlinks `dotai` into
  `~/.claude` and starts the `brain` sync service; `qmd collection add` + `qmd embed`
  build the local index (~2GB GGUF in `~/.cache/qmd`).
- **Steady state — capture:** session ends → Stop hook digests → commit + push
  `log/` to `main`. Other devices auto-pull.
- **Steady state — recall:** prompt arrives → agent queries the brain (qmd or
  index) when relevant → answers with the recalled note.
- **Steady state — promotion:** timer → lint agent drafts `log/`→`notes/` → PR →
  user merges.

## Error handling

- Pull uses `--ff-only`; local divergence → skip + desktop notify, never clobber.
- `log/` append-only with unique filenames → capture never conflicts across
  devices.
- Hallucination contained to `log/`; `notes/` only changes through a reviewed PR.
- qmd absent or failing on NixOS → brain degrades gracefully to index + direct
  file reads; no hard dependency.

## Testing / acceptance

- [ ] **qmd works on NixOS:** `qmd embed` + `qmd query` run on the target host; the
      qmd MCP tools are available in-session; `brain-recall` returns ranked hits via
      qmd and falls back to grep over `index.md`/`notes/` when qmd is down.
- [ ] `dotai` symlinked into `~/.claude` via `mkOutOfStoreSymlink`; editing
      `CLAUDE.md` is live without a rebuild; volatile `~/.claude` untouched.
- [ ] Stop hook writes a provenance-stamped digest to `brain/log/`, commits, and
      pushes to `main` at session end.
- [ ] From an unrelated directory, the agent recalls a `notes/` fact relevant to
      the prompt (proves global awareness + retrieval).
- [ ] Promotion timer opens a PR on `brain` proposing `log/`→`notes/`; merging it
      updates canon; nothing reaches `notes/` unreviewed.
- [ ] Commit + push on machine A, auto-pull on machine B → B recalls the new
      knowledge, no token cost for sync.
- [ ] graphify timer + MCP removed; auto-memory facts migrated into `brain/notes/`.
- [ ] No paid embedding API; retrieval is local; no secrets in any repo.

## Out of scope

- Knowledge base over external sources / article ingest (`raw/`) — separate
  project.
- Per-prompt auto-recall hook — rejected for latency + context pollution; recall
  is on-demand.
- Bidirectional auto-push of canon — rejected; promotion is a reviewed PR.
- macOS (~2026-09) — the shell scripts are portable; nix-darwin + launchd
  replaces the systemd user timer when the MacBook arrives. Not built now (YAGNI).
