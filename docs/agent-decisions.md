# Agent decisions

## 2026-10-15 - PR #284: Homebrew review follow-up

Goal: resolve the verified requests in [review 5438863505](https://github.com/zachlatta/freeflow/pull/284#pullrequestreview-5438863505) while keeping installation support separate from release automation.

Constraints: preserve the existing PR branch and history; do not push, publish replies, create another PR, install tools, modify generated changelogs, or claim that upstream maintainers have accepted distribution ownership. Review uses the current branch and public release artifacts without provider credentials.

Decisions: remove the Homebrew auto-bump step from the release workflow. Keep the cask and installation documentation independently reviewable. Pin the cask to the current stable release, v1.3.1, after computing the downloaded DMG's SHA-256 and comparing it with GitHub's release-asset digest. Run the existing checks plus Homebrew style and audit where the installed tools support them without installation.

Distribution: [issue #283](https://github.com/zachlatta/freeflow/issues/283) still has no maintainer decision. Preserve the in-repository `zachlatta/freeflow` tap as this PR's proposal and make its pending status explicit. Do not describe the path or manual update ownership as approved.

Rejected alternatives: do not choose a dedicated tap or official Homebrew cask location without upstream approval. Do not keep a release job that pushes directly to `main` inside an installation-support change. Do not replace the exact checksum with `:no_check`, infer approval from silence, or bootstrap Homebrew developer dependencies automatically.

Risks: without approved update ownership, the pinned cask can become stale. This July branch may lack checks added later on trunk. Installed Homebrew developer dependencies may be missing or unwritable, so attempted style and audit checks may remain blocked rather than passed.

Acceptance criteria: the PR adds no cask-related release-workflow writes; the cask references the current stable release and verified DMG bytes; Homebrew style/audit and `make check` results are recorded accurately; `git diff --check` passes; unresolved upstream distribution decisions remain visible.

Unresolved questions: upstream maintainers must confirm the tap location and the team responsible for cask version/checksum updates. The requested `make check` target is absent from this branch; determine whether an ordinary merge of current trunk is appropriate before adding or inventing checks.

### Draft follow-up for issue #283

PR #284 now proposes installation support independently of release automation. The proposed initial location remains `Casks/freeflow.rb` in `zachlatta/freeflow`, used with `brew tap zachlatta/freeflow https://github.com/zachlatta/freeflow` and `brew install --cask zachlatta/freeflow/freeflow`.

Proposed ownership: the upstream release maintainers review a cask update PR for each stable release, updating its version and the SHA-256 computed from the published universal DMG. A contributor may prepare that PR, but the proposal does not assign maintainership to anyone who has not accepted it. Until ownership and the location are confirmed, the DMG remains the confirmed distribution path. A dedicated tap or official Homebrew distribution remains an upstream decision.

Please confirm whether this in-repository tap and manual, reviewed update process are supported, or select a different location and owner. This is a local draft and has not been posted.

### Separate release-automation proposal

The earlier commits proposed updating the cask after publishing a release, using the release job's repository write permission and retrying a push to `main` when another commit won the race. That automation is removed from this PR. Any future proposal needs separate review of ownership, protected-branch compatibility, release ordering, failure recovery, and whether updates should be opened as pull requests. No replacement automation is implemented or authorized here.

### Implementation and verification

The missing-check-target question is resolved by the authorized ordinary merge of current `upstream/main`, commit `5795698`. The merge preserved published history and completed without conflicts. Its existing `make check` target runs application typechecking, the synthetic fixture test suite, and configuration/shell validation.

Downloaded `https://github.com/zachlatta/freeflow/releases/download/v1.3.1/FreeFlow.dmg`: 11,663,498 bytes, SHA-256 `17392f0dbc64921d67208e81e8e4b81963284ac673be7a812f7323255b8f5fe6`. This independently computed digest matches GitHub's public release-asset digest. Before the edit, the old cask version and checksum both failed comparison; after the edit, both match.

The release workflow is now byte-identical to `upstream/main`, preserving publication and cleanup without a Homebrew write step. `ruby -c Casks/freeflow.rb` passes. Homebrew's native `Cask::CaskLoader::FromContentLoader` loads the cask and resolves v1.3.1, the exact verified checksum and release URL, `auto_updates: true`, and macOS >= 13.

`brew info --cask --json=v2 /private/tmp/freeflow-pr284/Casks/freeflow.rb` rejects an untapped path. No global tap was created. `brew style` and `brew audit` are blocked at prerequisite inspection: Homebrew 7.0.4 lives in the read-only Nix store, no RuboCop gem specifications are installed, and both commands unconditionally call `install_bundler_gems!`. They were not invoked because that would attempt unauthorized dependency installation. Native cask loading is separate evidence and does not replace style/audit. Homebrew automatically enabled developer mode during the first `brew ruby` invocation; `brew developer off` restored the prior setting, and subsequent loading used a process-local developer flag.

The first `make check` attempt completed application typechecking and reached test compilation, then the local 180-second execution limit expired. A fresh run with a 600-second limit exited 0 in 115 seconds: `FreeFlowTests passed`, both property-list files passed lint, and shell validation completed. It emitted existing `AVAudioConverter` Sendable availability warnings at `Sources/AudioRecorder.swift:105`, `:106`, `:513`, and `:837`, plus a Ruby `ffi-1.16.3` extension warning. No tool installation or application-source changes were made for these environment/upstream warnings.

`git diff --check` passes. `graphify update .` rebuilt the isolated AST cache with 1,448 nodes and 3,354 edges after the changes. The cache symlink, `.superpowers/`, and `.env.*` are ignored; no cache or credentials are committed.
