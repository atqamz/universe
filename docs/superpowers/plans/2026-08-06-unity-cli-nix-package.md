# Nix-managed Unity CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package Unity CLI as a pinned Nix derivation and install it beside the existing Nix-managed Unity Hub without managing Unity Editors in the Nix store.

**Architecture:** A local `unity-cli` package fetches Unity's versioned standalone binary, patches it for NixOS, and wraps its declared runtime tools. Home Manager installs that package and stops exposing the legacy user-installed binary; a manifest-aware updater integrates with the existing weekly package workflow without changing other packages' update paths.

**Tech Stack:** Nix, Home Manager, `stdenv.mkDerivation`, `autoPatchelfHook`, `makeWrapper`, `nix-update`, GitHub Actions.

## Global Constraints

- No comments in `.nix` files.
- Nix owns only Unity Hub and Unity CLI; Unity owns Editors, modules, projects, authentication, and mutable state.
- Fetch only Unity's official versioned standalone Linux binaries with fixed hashes.
- Support the flake's declared `x86_64-linux` system.
- Preserve the existing Unity Hub GPU offload, FHS environment, desktop entry, and `unity-editor` launcher.
- Do not delete anything under `~/.unity`.
- Run `nix fmt`, then `nix flake check` before completion.

---

### Task 1: Package the Unity CLI binary

**Files:**
- Create: `pkgs/unity-cli/default.nix`
- Modify: `pkgs/default.nix`

**Interfaces:**
- Consumes: Unity's `latest-beta.json` version and fixed x86-64 SHA-256 hash.
- Produces: flake package `unity-cli` with main executable `$out/bin/unity`.

- [ ] **Step 1: Verify the package is absent**

Run:

```bash
nix build .#unity-cli
```

Expected: FAIL because the flake has no `unity-cli` package.

- [ ] **Step 2: Add the minimal derivation**

Create `pkgs/unity-cli/default.nix` for `x86_64-linux`, version `1.0.0-beta.3`, and the URL:

```text
https://public-cdn.cloud.unity3d.com/hub/prod/cli/1.0.0-beta.3/unity-linux-x64
```

Use `sha256-m4mqpaZ26OW9ajhEqTmN77ljvTSVGGRFpGSkcFflTqM=`.

Use `fetchurl` with `executable = true`, install the source as `$out/bin/.unity-unwrapped`, and let `autoPatchelfHook` patch the copied ELF. Wrap it as `$out/bin/unity` with:

```nix
--prefix PATH : ${lib.makeBinPath [ gnupg unzip ]} \
--set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
```

Set `meta.license = lib.licenses.unfree`, `meta.mainProgram = "unity"`, `meta.platforms` to both supported Linux systems, and `meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ]`.

Add `"unity-cli"` to the generated package names in `pkgs/default.nix`.

- [ ] **Step 3: Build and smoke-test the package**

Run:

```bash
nix build .#unity-cli --print-build-logs
./result/bin/unity --version
./result/bin/unity --help >/dev/null
```

Expected: the build succeeds, version output is `1.0.0-beta.3`, and help exits zero.

- [ ] **Step 4: Verify the binary no longer needs nix-ld**

Run:

```bash
nix shell nixpkgs#patchelf -c patchelf --print-interpreter result/bin/.unity-unwrapped
```

Expected: the interpreter is a `/nix/store/...-glibc-.../lib/ld-linux-...` path, not `/lib64/ld-linux-x86-64.so.2`.

- [ ] **Step 5: Commit the package**

```bash
git add pkgs/default.nix pkgs/unity-cli/default.nix
git commit -m "feat(pkgs): package Unity CLI"
```

### Task 2: Install the Nix package through Home Manager

**Files:**
- Modify: `modules/home/unity.nix`

**Interfaces:**
- Consumes: `pkgs.unity-cli` from the repository overlay.
- Produces: `unity` on the Home Manager profile path without `~/.unity/bin` in `home.sessionPath`.

- [ ] **Step 1: Remove the legacy path and add the package**

Delete `config` from the module arguments because it becomes unused. Remove:

```nix
sessionPath = [ "${config.home.homeDirectory}/.unity/bin" ];
```

Add `pkgs.unity-cli` to the existing `home.packages` list without changing the Unity Hub or `unity-editor` derivations.

- [ ] **Step 2: Evaluate the affected Home Manager configuration**

Run:

```bash
nix eval .#nixosConfigurations.$(hostname).config.home-manager.users.atqa.home.packages --apply 'packages: builtins.any (package: (package.pname or "") == "unity-cli") packages'
```

Expected: `true`.

- [ ] **Step 3: Confirm the old path is absent from the source**

Run:

```bash
rg -n '\.unity/bin|sessionPath' modules/home/unity.nix
```

Expected: no matches.

- [ ] **Step 4: Commit the Home Manager integration**

```bash
git add modules/home/unity.nix
git commit -m "feat(home): manage Unity CLI with Nix"
```

### Task 3: Integrate manifest-aware updates and run final verification

**Files:**
- Modify: `pkgs/unity-cli/default.nix`
- Modify: `.github/workflows/update-packages.yaml`
- Modify: `parts/packages.nix`

**Interfaces:**
- Consumes: `https://public-cdn.cloud.unity3d.com/hub/prod/cli/latest-beta.json` with string field `.version`.
- Produces: `passthru.updateScript`, invoked only for Unity CLI by the weekly workflow through `nix-update --use-update-script`.

- [ ] **Step 1: Add the package-specific updater**

Use `writeShellApplication` with runtime inputs `curl`, `jq`, and `nix-update`. Its script must fetch the official beta manifest, reject a missing or empty `.version`, then execute:

```bash
nix-update --flake \
  --override-filename pkgs/unity-cli/default.nix \
  --version "$version" \
  unity-cli
```

Expose the generated executable as a one-element `passthru.updateScript` list.

- [ ] **Step 2: Make the weekly workflow honor package update scripts**

Build an `update_args` shell array in `.github/workflows/update-packages.yaml`. Add `--use-update-script` only when `PACKAGE` is `unity-cli`, then expand the array in the existing `nix-update` invocation. This preserves the direct updater path for existing packages whose generic update scripts cannot re-enter this repository as a flake.

Import the per-system package set in `parts/packages.nix` with an `allowUnfreePredicate` limited to `unity-cli`, so flake package evaluation accepts the package's accurate proprietary license metadata without globally allowing unfree packages.

- [ ] **Step 3: Verify updater evaluation and current-version behavior**

Run:

```bash
nix shell nixpkgs#nix-update -c nix-update \
  --flake --use-update-script \
  --override-filename pkgs/unity-cli/default.nix \
  unity-cli
git diff --exit-code -- pkgs/unity-cli/default.nix
```

Expected: the update script builds, reads `1.0.0-beta.3`, and leaves the current package unchanged.

- [ ] **Step 4: Verify an existing standard updater still works**

Run:

```bash
nix shell nixpkgs#nix-update -c nix-update \
  --flake --use-update-script \
  --override-filename pkgs/codedb/default.nix \
  codedb
git diff --exit-code -- pkgs/codedb/default.nix
```

Expected: the existing `nix-update-script` executes successfully. If upstream has released a newer `codedb`, inspect and revert only that updater-generated version bump before continuing.

- [ ] **Step 5: Format and run the full flake gate**

Run:

```bash
nix fmt
nix flake check --print-build-logs
```

Expected: both commands exit zero.

- [ ] **Step 6: Commit updater integration**

```bash
git add pkgs/unity-cli/default.nix .github/workflows/update-packages.yaml
git commit -m "ci: update Unity CLI from its manifest"
```

- [ ] **Step 7: Inspect the final state**

Run:

```bash
git status --short
git log -5 --oneline
```

Expected: the worktree is clean and the plan's implementation commits are present.
