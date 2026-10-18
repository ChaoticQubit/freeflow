# Homebrew Zap User-Data Retention Implementation Plan

> Use `superpowers:executing-plans` to implement this single task in the existing isolated worktree. Root owns the final review and publishing decision.

**Goal:** Preserve retained FreeFlow recordings and pipeline history during optional Homebrew zap cleanup.

**Architecture:** Narrow the existing declarative Application Support trash target to the transient recording flag. Exercise the native cask's parsed zap directives against invented files in a bounded temporary home; do not introduce application cleanup code or another test framework.

**Tech stack:** Existing Homebrew Ruby cask loader, standard-library Ruby filesystem operations, and the repository's existing Make/Swift checks.

**Spec:** `docs/agent-decisions.md`, topic `2026-10-17 - PR #284: retain user data during Homebrew zap`.

## Global constraints and engineering synthesis

Continue `add-homebrew-cask` at `6cd33d5a4fa0acf2f406f31de510bd70e82d3b70`; no history rewrite, push, PR publication, tool installation, extra reviewer, personal-data access, or real uninstall/zap. Preserve `.serena/`, the release pin/checksum, other zap targets, README, release automation, and prior decisions.

Apply software-practices first: use evidence for the storage contract, preserve one focused reviewable change on the existing PR branch, test observable retained bytes with real local files, and hand the frozen result to root. A feature flag is inapplicable to a completed cask-path correction. Apply ponytail next: the existing Homebrew path directive is the first sufficient rung, so change one value without adding cleanup infrastructure. Apply tiger-style last: constrain scratch operations to a fresh temporary home, reject paths escaping that root, assert retained bytes and absent transient state, and keep the verification bounded.

## Review focus

The synthetic retention check covers saved audio, the SQLite history file and sidecars, additional sibling files, the transient flag, and the unchanged cache/HTTP-storage/preferences cleanup targets. Actual installation, OS Trash integration, style/audit, and root's final review remain explicitly separate qualification.

## Task 1: Preserve saved data during zap cleanup

**Files:** Modify `Casks/freeflow.rb:24`; append the required decision record and this plan. Keep the runnable reproduction and logs in `/private/tmp/freeflow-coderabbit-20261017/pr284-evidence/`.

**Interfaces:** Consume the native cask loader's parsed zap `trash` paths. Produce the same cask with only `~/Library/Application Support/FreeFlow/is-recording` selected under Application Support.

- [x] Write and run a synthetic-home retention check before editing the cask. It must fail on retained audio/history leaving their original paths, with fixture bytes preserved in synthetic trash for inspection.
- [x] Replace the single broad Application Support trash value with the transient `is-recording` path. Run the identical retention check and verify exact saved-file bytes, sibling preservation, and transient cleanup.
- [x] Run `ruby -c Casks/freeflow.rb`, the native Homebrew content-loader check, and `make check` with synthetic `HOME` and isolated Swift/Clang caches. Record full logs and exit codes; do not install style/audit dependencies.
- [x] Run `git diff --check` and `graphify update .`; inspect changed-file scope and write an evidence receipt. Root owns further review authorization and the final post-review graph refresh.
- [x] Commit the verified scoped fix and required docs without co-author metadata. Record final SHA, `git diff --numstat`, tracked/index cleanliness, and preserved `.serena/` in the root handoff.
