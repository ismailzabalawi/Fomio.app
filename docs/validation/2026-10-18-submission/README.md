# Submission preparation validation — 2026-10-18

Working tree based on `b62aef5`. Xcode 27.1 (27A9275), iPhone 17 Pro Max / iOS 26.1 Simulator; local signed archive uses iPhoneOS 27.1 SDK, generic iOS, Release. Backend reference `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Current public site HTML advertises a different revision; see [API evidence](../../discourse-api-reference.md).

- **96 unit/contract tests passed**, zero failures, four opt-in live tests skipped. Includes callback URL registration and deletion identity, permission, member credentials and malformed-success checks. Result bundle: `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/test_sim_2026-10-17T22-19-15-802Z_pid85594_b5d57693.xcresult`.
- **One targeted UI test passed**, zero failures/skips: Me → Delete account → restricted-account explanation → Close, retaining the signed-in fixture session. Result: `test_sim_2026-10-17T22-22-26-550Z_pid85594_bc6d9b65.xcresult` in the same directory. Its first attempt failed in the existing launch helper, which waited for Home while the test started directly on Me. The corrected test launches Home and taps Me normally. No actual account deletion was attempted.
- Restricted-account deletion capture was exported from the passing XCTest attachment and visually inspected. Native Form, heading, explanation, Close and support action are visible without clipping. This is fixture UI evidence, not proof of deployed permission or deletion.
- Release simulator build/launch succeeded before deletion was added. The final deletion code compiled in the passing Debug tests and final device Release archive. No claim of a final full UI regression or physical-device run is made.
- **Final signed archive succeeded** at `.build/submission-0.8.0-6/Fomio-final.xcarchive`. The initial sandboxed attempt could not access provisioning. Running with the existing Xcode account and provisioning updates succeeded. Local archive verification passed using the system trust store; the archive's development signing is replaced by distribution signing during export.
- **App Store Connect local export succeeded**, destination `export`, method `app-store-connect`, automatic signing, existing team. Output: `.build/submission-0.8.0-6/export/Fomio.ipa`. No upload or review submission occurred. Exported IPA code signature verification passed, application/team identifiers match `LK9253R3XB.com.fomio.mobile`, `get-task-allow` is false and `beta-reports-active` is true.
- Source, archive and extracted IPA pass `scripts/submission_preflight.py`. Packaged privacy manifest matches source; Info resolves 0.8.0 (6), HTTPS site, callback scheme and icon. Build-number availability and Connect server validation were not checked.
- Archive warnings: existing compile-time unreachable fixture branch and skipped AppIntents extraction without an AppIntents dependency. No archive errors. Logs: `/private/tmp/fomio-submission-archive-final.log`, `/private/tmp/fomio-submission-export.log` (temporary). Archive/export artifacts are ignored local build outputs.

**Initial build 6 audit (superseded by the build 7 follow-up below):** public policies, safety controls and Connect declarations were incomplete. See [submission packet](../../app-store-submission.md). A valid signed package does not establish App Review readiness.


## Build 7 follow-up

- Native report reasons use dynamic IDs and fresh permissions, custom required details and matching server acted receipts. Server Ignore uses string levels, Forever expiry and session readback. UI supports unblock and hides blocked authors across loaded content. Native self-deletion and support remain permission-controlled.
- **Final iPad regression: 102 passed, 0 failed, 4 opt-in live skips.** 101 unit/contract tests plus the report → block → unblock UI journey. Result `test_sim_2026-10-18T04-16-07-616Z_pid85594_e185b9f7.xcresult`. Earlier iPad run `test_sim_2026-10-18T04-08-12-353Z_pid85594_e92ea3c4.xcresult` passed 105 tests including four UI journeys. Phone safety UI passed separately. These are separate runs, not one combined suite.
- Guest live read passed. After user native sign-in, expanded **member live read passed with no skips**, including dynamic report options, Ignore permission and deletion eligibility endpoint, along with Saved/notifications/profile/feed. Result `test_sim_2026-10-18T04-26-38-018Z_pid85594_d9eb4a93.xcresult`. No live report/block/delete was sent.
- **Release archive, local distribution export and upload succeeded**: `.build/submission-0.8.0-7/Fomio.xcarchive`, `.build/submission-0.8.0-7/export/Fomio.ipa`. System-trust signature verification and packaged preflight pass; `get-task-allow=false`, `beta-reports-active=true`, correct bundle/team. Apple reported upload success at 07:25 Asia/Amman. Build 7 finished processing and was selected/saved in the 0.8.0 draft. No App Review submission.
- Live website updates authorized by owner: About mailto support; Privacy native/service data and 90-day owner-supplied log retention; Terms native scope and template cleanup, preserving company/empty jurisdiction settings. Actual log rotation not independently verified. Approved reporting and Ignore groups now include trust_level_0. Self-delete max saved as 2,000,000,000 (server rejected 2,147,483,647 as above its supported maximum).
- Connect privacy labels published: 8 linked/no-tracking types, app functionality throughout and search analytics additionally; old audio/unlinked declarations replaced. Native listing text/version/review notes saved; existing review credentials/contact, manual release and categories preserved. Content-frequency age answers preserved; newly required social-media yes and system age-range gating no recorded.
- Screenshot capture helper initially matched a category button (`topic-category-*`) when looking for a topic, then waited for an offscreen subcommunity. It now matches exact numeric topic IDs and any loaded root community. These were test-selector failures, not app crashes. Required iPhone capture passed on iPhone 17 Pro /iOS26.1; full-resolution images are under `docs/app-store-assets/0.8.0/iphone/`.
- System disk became full during iPad asset compilation. Project build/test caches were preserved on the external project drive under `.build/submission-0.8.0-7/` (`MCPDerivedData`, `test-products`, `relocated-caches`). Original result bundles/logs remain in their recorded XcodeBuildMCP locations. No personal files or simulator data removed.

Website/Connect evidence: About, Privacy, Terms, privacy labels, age rating, report permission, Ignore permission, deletion limit.


### Outstanding environment and acceptance work

The iPhone capture test passed with three 1206×2622 live native screenshots. The 13-inch iPad run failed during asset compilation with errno 28 (no disk space); retry after cache relocation reached simulator preparation but stalled as Macintosh HD fell back to approximately 120 MB free. That stalled xcodebuild process was interrupted. The browser kernel also reset during the upload attempt and Connect’s per-app pages later stalled. No screenshot upload was confirmed. User was asked to free at least 5 GB before retrying. This is an environment blocker, not a passing iPad asset run. Required screenshot slots and old optional Expo image replacement remain incomplete.

Build 7 itself is processed and selected/saved. No review submission. Pending: screenshot completion, final physical/TestFlight acceptance and verified review-account access. Actual server-side reporting delivery, Ignore mutation and destructive deletion were not exercised on real community data.


### Resumed after disk recovery

Owner freed system space (11 GB available at resume). `screenshots-ipad-recovered.xcresult` passed the live capture journey on iPad Pro 13-inch / iPadOS 26.1: 1 test, 0 failures, 0 skips. Native full-resolution images exported and visually inspected. Three 1206×2622 iPhone screenshots and two 2064×2752 iPad screenshots are uploaded and confirmed by Connect’s required-slot counts. The iPad Communities capture caught a toolbar transition and was excluded; its optional follow-up run stalled during simulator preparation and was interrupted. No app code changed for this capture work.

Old optional large Dynamic Island and large Face ID Expo screenshot sets were removed from this version through Media Manager. Connect explicitly confirms these removals preserve the Asset Library originals. No optional iPad assets were configured. Both required slots are now populated. Proof: iPad assets, iPhone assets.

Build 7 distribution IPA SHA256: `2c3b7ed4efacb21ddbecccfa9ae6824a06584f191e76ed82a6a89c6d4edb9182`. Capture-helper changes are test-only; the uploaded app binary remains the verified build 7. Physical/TestFlight acceptance and review-account login validation remain outside the performed checks.


Automatic approval review rejected **Add for Review** because it may queue/change review state and the user authorized preparation. No Add for Review or final submission was performed. All unaffected asset/metadata work was completed. Explicit owner authorization is needed for the next submission-state change.


### Add for Review accepted after explicit owner approval

Owner explicitly approved clicking Add for Review for 0.8.0 / build 7. The action succeeded at 08:02 Asia/Amman on 2026-10-18. Connect displays **Ready for Review** and **This app version has been added for review**. Draft Submission shows **Item Ready to Submit**, **iOS App 0.8.0**, **0.8.0 (7)** and a separate **Submit for Review** button. Final Submit for Review was not clicked. Manual release remains selected. Saved confirmation.
