# Agent decisions

## 2026-10-15 - PR 289 scriptable settings review

Topic: Address maintainer review 5438860817 on scriptable preferences.

Goal: Make the existing JSON preference compatibility reproducibly tested, correct the credential update recipe, and document current upstream settings.

Constraints: Work only on `scriptable-settings` in its isolated worktree. Preserve published history, existing Data encoding, launch-time loading, unrelated credentials, upstream functionality, and production preferences. Use synthetic local fixtures. Do not install tools, push, post replies, edit generated files, or request new macOS permissions.

Decisions: The maintainer's three concerns are valid. Merge current `upstream/main` rather than rebase, as authorized by the coordinating agent, to avoid rewriting published history. Preserve both the configuration guide and upstream Contributing section when resolving README. Move the existing JSON preference byte reader and `VoiceMacro` model into a small Foundation-only production file so the standalone test runner executes the actual codec. Keep Data writes and current invalid-JSON fallback behavior. Cover Data and string shortcut/macro input, missing and explicit IDs, invalid JSON and IDs, required fields, and round trips using isolated UserDefaults suites. Use macOS `plutil` to update credential dictionary entries in place after restricting permissions, with `umask 077` protecting newly created files and replacement files. Include development and release domains and credential directories, desktop screenshot fallback, and the recording timer.

Rejected alternatives: A fresh configuration layer, live reloading, a copied test codec, compiling the entire UI application into unit tests, truncating credentials with a heredoc, Python installation, and a history-rewriting rebase add risk or fail the review requirements.

Risks: A malformed external preference must retain existing fallback behavior. A malformed credential file must cause the recipe to stop before changing its contents. Permission changes cannot undo past exposure of an already-permissive file. Synthetic file tests cannot qualify microphone, Accessibility, clipboard, or global shortcut UI flows.

Acceptance criteria: Current upstream is integrated without losing either README section. The actual production codec is covered by deterministic tests in `make check`. Credential updates preserve unrelated entries and result in mode 600 for both existing and new files, including before new secret bytes are written. README inventory matches current source and identifies both preference domains and settings directories. `make check` and `git diff --check` pass. The coordinating agent completes the frozen-target code and security review before any push.

Unresolved questions: None for implementation. Signed-app permission-sensitive manual qualification remains a separate merge gate if requested by the maintainer.

Implementation ruling: Native `plutil -replace` interprets a new empty `{}` file as OpenStep and refuses to rewrite it. The in-place update decision above is superseded: transform a private temporary plist, convert it back to JSON, and atomically rename it over the destination only after both updates succeed. Restrict an existing destination before reading it. This also preserves the original JSON on parsing or intermediate-update failures.

Codec ruling: The extracted original reader failed the unsupported-type test because `UserDefaults.string(forKey:)` converted a Boolean to `"1"`. Restrict the fallback to an actual String from `object(forKey:)`; Data and String remain the supported storage formats. Existing JSON decoding and application fallback paths stay in place. Both production loaders call the extracted reader, and all application writes still use Data.

Execution evidence: `/private/tmp/freeflow-pr289-codec-red.log` records the Boolean coercion failure and `/private/tmp/freeflow-pr289-codec-green.log` records the subsequent passing standalone suite. Removing the production String fallback failed the focused harness in `/private/tmp/freeflow-pr289-string-fallback-red.log`. Requiring a macro UUID failed it with `keyNotFound` in `/private/tmp/freeflow-pr289-missing-id-red.log`. Both temporary mutations were restored. The tests compile the production file, with no copied codec. Expanded fixtures cover explicit and generated IDs through Data and String, malformed JSON, invalid UUIDs and required fields, Unicode/newlines, and saved round trips. The README recipe also runs against the documented FreeFlow Dev path and verifies that the release path is untouched.

Privacy boundary: Execute checks with both HOME and CFFIXED_USER_HOME set to `/private/tmp/freeflow-pr289-test-home`, plus isolated Swift module caches. Recipe subprocesses use their own temporary HOME and synthetic provider/key values. Do not run the app or access personal configuration. Root owns the normal and security reviews after the commit is frozen; neither review is started by this worker.

Verification outcome: The final `make check` passed using the synthetic HOME and approved sandbox escalation for Apple's SwiftUI macro server. Both whitespace checks passed. `graphify update .` refreshed the production codec and test sources. Configuration and Contributing each remain present once in README; CHANGELOG.md is unchanged from the merged upstream revision. The exact base, frozen head, files, evidence, and remaining manual/review gates are recorded in `/private/tmp/freeflow-review-20261015/pr289-terminal-result.md` after commit.
