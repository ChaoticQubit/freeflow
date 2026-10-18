# Credential Fixture Input Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. Track the steps below and retain external evidence in `/private/tmp/freeflow-coderabbit-20261017/`.

**Goal:** Prevent malformed-settings fixtures from writing unused credential input after the recipe has already rejected the settings.

**Architecture:** Keep the existing README-driven local process fixture. Represent omitted stdin as `Data?`, preserve the synthetic credential default, and close the pipe for both input modes.

**Tech Stack:** Swift Foundation, the installed Swift compiler, Make, the existing Bash/Ruby recipe, and synthetic local fixtures.

**Spec:** `docs/agent-decisions.md`, topic `2026-10-17 - PR 289 early-exit credential fixture input`.

## Global Constraints

Continue `scriptable-settings` from `5ecc90e6e92bdaa37ace06e275af907148a8dcb1`. Modify only `Tests/CredentialRecipeTests.swift`, this plan, and the decision record. Preserve all 16 registrations and all production/README behavior. Do not install tools, push, post comments, modify signals, or launch another review. Root owns review and publication. Use synthetic HOME/CFFIXED_USER_HOME and separate Swift caches. No feature flag is needed for a test-helper change.

## Review Focus

All malformed-settings cases must report the child's exact failure output and preserve original bytes with omitted input. Empty Data still tests cancellation. Default and explicit bounded credentials still persist exactly. Unwritable-directory and process-argument checks keep their original input. Tests/TestMain.swift retains 16 distinct registrations exactly once at HEAD.

## Task 1: Omitted stdin for pre-input failures

**Files:** Modify `Tests/CredentialRecipeTests.swift:86-99` and `:186-219`. Update this plan and the decision record. Keep executable evidence and the final handoff outside the checkout.

**Interfaces:** Consume the actual README recipe and existing `expectFailure`/`expectSuccess` helpers. Produce `runRecipe(home: URL, appName: String = "FreeFlow", input: Data? = Data((syntheticKey + "\n").utf8), observeArguments: Bool = false) throws -> RecipeResult` without changing the result or caller assertions.

- [x] Step 1: Demonstrate a live process with a closed stdin reader using a synthetic local child and the same Foundation write API. Expected: the old guarded write fails instead of reaching the intended result assertion. Retain the reproduction and output externally.
- [x] Step 2: Make the malformed-settings fixture call `runRecipe(home: directory, input: nil)` before changing the helper. Run a focused compile and retain the unsupported-input diagnostic. Use Step 1's synchronized write failure as the behavioral red evidence; the compiler diagnostic independently establishes that the old helper cannot express omitted input.
- [x] Step 3: Change the helper input to `Data?` and write only for `process.isRunning` plus non-nil input; retain the unconditional pipe close. Run the same behavioral harness and the actual focused `CredentialRecipeTests` runner. Expected: both pass; all 30 existing recipe invocations retain their assertions.
- [x] Step 4: Run the existing native PTY check and `make check`, inspect complete logs, run `git diff --check`, and refresh the graph. Expected: all commands pass, no unexpected source/helper removal, and 16 unique registration names remain once each.
- [x] Step 5: Update this plan and the decision record with outcomes, commit the three scoped files, verify registration counts and cleanliness at HEAD, refresh the graph for the concrete committed state, and write `/private/tmp/freeflow-coderabbit-20261017/pr289-handoff.md`. Expected: one clean local fix commit with exact evidence and review limitations.

## Execution Ledger

Pre-flight: no shared interfaces with another implementation task. All nine `runRecipe` call sites have been traced before editing. Existing branch and starting HEAD match the assignment.

Ruling: Root explicitly assigned inline implementation and retained review authority. Continue the authorized fix without another plan-approval pause or reviewer launch. Keep this task's execution record here and in the requested external handoff rather than creating another checkout-local tool workspace.

Ruling: The old helper has a nonoptional Data contract, so an actual nil caller necessarily fails compilation before runtime. Keep that diagnostic distinct from the behavioral red evidence: a synchronized synthetic child closes stdin while remaining alive, and the old Foundation write guard terminates with SIGPIPE. The fixed nil-input guard reaches the expected child status/output assertions. The real fixture then verifies unchanged original settings across all eight malformed-settings cases.

Task 1 verification: The focused runner passes all 30 actual README recipe invocations. Native PTY success, interrupt, and EOF pass. `make check` exits 0 in 49.174 seconds with the existing AudioRecorder Sendable warnings and Ruby ffi notice. The first `graphify update .` exits 0 with 1595 nodes, 3803 edges, and 167 communities. Raw logs reside in the assigned external evidence directory. Final commit, whitespace, preservation, and HEAD checks are recorded in the handoff.
