# Independent clean-suite review — 2026-10-19

Claude has finished. Reviewed `claude/fomio-release-integration` at `293f3fa`, a clean worktree, against the prior audit and the raw test artifacts. Local `origin/main` remains `eef6b2f`. No push or upload was performed by this review.

## Review outcome

No blocking finding in the UI synchronization change. Relative to `4f52256`, the only code change is in `FomioUITests/FomioUITests.swift`: keyboard dismissal now asserts that the software keyboard has returned with the toggle above it, then taps the settled control. The shared settled-tap helper also waits for this geometry when a keyboard exists. Original keyboard-disappearance, button-label, hittability and swipe/draft-protection assertions remain. No test was removed, skipped or broadly retried to obtain the final run. App code, the notification corrections and their regression tests are unchanged.

The Feed accessibility test is unchanged. Claude documents diagnostic evidence of outside simulator touches and a subsequent competing test runner, rather than changing the test to tolerate a missing menu. Exact historical input-source attribution was not independently reconstructed by this review; the decisive acceptance evidence is that this unchanged journey passes in both complete runs, with all coverage retained.

## Independently inspected result bundles

Used `xcrun xcresulttool get test-results summary --path <bundle> --compact`, checked raw xcodebuild logs and the commands that launched the runs.

| Bundle under integration `.build/` | Simulator | Executed | Passed | Skipped | Failed |
| --- | --- | ---: | ---: | ---: | ---: |
| `isolated-complete.xcresult` | Fomio Isolated Suite iPhone 17, BA47EA08…, iOS 27.0 | 183 | 176 | 7 | 0 |
| `complete-final2.xcresult` | Fomio Release iPhone 17, CAB241D5…, iOS 27.0 | 183 | 176 | 7 | 0 |

Both summaries say `Passed`, with zero expected failures, zero failed tests and no runtime warnings. Both raw logs end `TEST SUCCEEDED`. Each command runs the complete scheme without `only-testing` or `skip-testing` exclusions. Each run includes 133 unit/contract tests (129 passed, four skipped) and 50 UI tests (47 passed, three skipped). The formerly failing Feed accessibility and Swipe dismissal journeys explicitly pass in the isolated log.

Seven skips are existing explicit opt-ins: four deployed Discourse contract tests, two store-capture journeys and one live UI read journey. They were not introduced by the UI fix.

Code equivalence: `git diff df22e03 HEAD -- Fomio FomioTests FomioUITests project.yml Fomio.xcodeproj` is empty. `df22e03` contains the tested helper change; later commits change only documentation. The isolated process watcher records that simulator's app/runner processes without another runner targeting that simulator. The two successful runs overlapped in wall-clock time on the same host, on separate simulators with separate derived data; “isolated” here means simulator/build isolation, not exclusive use of the whole Mac.

## Release assessment

The previously required clean complete-suite verification is now satisfied for the inspected iPhone simulator code. The UI-test blocker from the prior review is cleared, and the local follow-up commits are suitable for the user's push decision.

This does not certify an App Store upload or production push delivery. Marketing version remains undecided because 0.8.0 is closed. Existing live notification/APNs, iPad and physical-device acceptance limitations remain as documented. This audit inspected artifacts rather than launching another full simulator suite, and did not select a marketing version or initiate release work.
