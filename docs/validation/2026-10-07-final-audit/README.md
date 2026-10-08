# Final native audit — 2026-10-07

**Original verdict: not ready for release acceptance.** The four findings and catalogue verification gap were subsequently corrected and locally revalidated; see [audit fixes and remaining gates](../2026-10-07-audit-fixes/README.md). The evidence below records the original audit. Audit performed with the Build iOS Apps plugin's XcodeBuildMCP tools against app commit `a93cb620060e8d0a0ea6beb476639fd4e7ae9ce3`, on the already-booted iPhone 17 Pro / iOS 26.1 simulator. Dates use Asia/Amman; result-bundle filenames use UTC and therefore start with 2026-10-06. The auditor made no production-code or backend edits. Concurrent composer/catalogue and localization edits appeared later in the workspace; targeted coverage of that newer working tree is recorded below. The baseline results and first Release build initially applied to the starting commit. Temporary diagnostic tests were removed after execution; their exact source is preserved as [audit probes](refresh-probe.swift.txt). An unrelated `docs/design/topic-card-prototype.md` appeared during the audit and was left untouched.

## Findings

### 1. P1 — A denied refresh retains the previously permitted topic and controls

[DiscussionState.swift:57](</Volumes/Develop/Projects/Fomio Swift/Fomio/Features/DiscussionState.swift:57>) records a refresh error without invalidating `page` or its nodes. [DiscussionView.swift:18](</Volumes/Develop/Projects/Fomio Swift/Fomio/Features/DiscussionView.swift:18>) still renders the cached topic whenever `page` exists; the access-denied screen at line 97 only applies when the page is nil. A synthetic transport probe loaded a valid topic with `can_create_post=true`, then returned HTTP 403 on refresh. The state retained its opening text and `canReply=true` despite `errorKind=.denied`. The renderer consequently uses old content and controls, with a “Couldn’t load more” message rather than the denial screen. This was established by state reproduction and view inspection, not by revoking a real member's permissions.

Invalidate/hide the retained page and topic controls on authoritative authorization/visibility failure, while preserving the intended offline recovery behavior for network failures. Add a regression asserting the denial screen after a previously successful load. Server enforcement remains intact; this finding concerns stale client display and permission state.

### 2. P2 — Successful refresh leaves removed child replies in expanded branches

[DiscussionState.swift:54](</Volumes/Develop/Projects/Fomio Swift/Fomio/Features/DiscussionState.swift:54>) replaces roots but retains child IDs, nodes and loaded markers. `ingest` only replaces a child list when the response embeds nonempty children. A local fixture probe loaded an expanded root with two children, removed one child from the repository, and successfully refreshed. The root's new child count was one, yet the expanded branch still contained both old child IDs and the removed reply's text. `ThreadBranch` continues rendering that list while the root still has children.

Reconcile/invalidate branch caches during a successful refresh and refetch previously expanded branches as needed. Preserve old data only for transient refresh failures. A regression should check both removed replies and changed child permissions/content.

### 3. P2 — The keyboard-focus journey fails repeatedly in this audit

`testKeyboardBarNextAndKeepEditing` failed after entering “First line / Second line”: XCTest could not type the next text because the body had no keyboard focus. This repeats the earlier full-suite failure even though isolated reruns previously passed. The failure is an unresolved runtime/test-isolation regression; its production cause has not been established. A second batch containing only the keyboard test and the live native navigation test failed at the same point, without an Arabic test preceding it in that batch. Yesterday’s isolated passes do not resolve the current repeated failures. Distinguish responder loss, retained simulator keyboard state and test synchronization before changing focus logic.

### 4. P2 — Arabic phone composer does not rotate to landscape

`testArabicComposerPreservesMixedTextAcrossModesAndRotation` again timed out waiting for a landscape window after the orientation request. [Captured outcome](arabic-rotation-failure.png) remains portrait. The test keeps mixed Arabic/Latin text intact before that failure. Prior iPad orientation-request tests did not assert actual landscape geometry and cannot close this phone gate. No orientation workaround was applied during this audit.

### 5. Verification gap — Catalogue test failed during active search

The concurrently added `testComposerCatalogueQuickQuoteAndSearchRecovery` reaches the inserter, finds Photo/Quote and successfully searches for Poll, then fails to find `composer-insert-cancel` while search is active. The accessibility snapshot contains the system search Close control but no inserter Cancel identifier. The first attempt ended in test-runner termination/Mach IPC failure; the isolated retry reached this specific UI failure. This establishes a failed journey, not that every user cannot dismiss the sheet. An external test edit subsequently added an explicit native-search cancellation before sheet cancellation. This may explain the failure as a test interaction issue; the edited version requires a new run before closing the gate. The initial fingerprint no longer matches the test file; production composer and localization fingerprints still match.

## Verification

| Check | Current result |
| --- | --- |
| Debug unit/contract suite | 73 passed, zero failed; three live checks intentionally skipped |
| Nine selected native fixture journeys | Seven passed; rotation and keyboard focus failed |
| Follow-up keyboard/live native UI batch | Live category → child → About → topic passed; keyboard focus failed again |
| Live anonymous integration reads | Passed: palette, directory, root feeds, Latest pagination, exact contexts/children, search targets and missing-topic handling |
| Live stored-member integration reads | Passed: current user, palette/categories, profile, Saved, notifications and topic |
| Diagnostic cache probes | Both reproduced the defects above; passing assertions describe observed defects, not acceptance |
| Release simulator build | Succeeded; one unreachable-code warning at FomioApp.swift:18 because `fixtureMode=false` in Release |
| Concurrent catalogue retry | Failed during active search; subsequently edited test not revalidated |
| Concurrent remaining layout batch | Debug test build succeeded; waiting call terminated after stalled overlapping Simulator execution; no completed functional result |

The successful fixture UI journeys cover category expansion/About/child Create context, category filter/Back retention, dark accessibility theme layout, protected draft creation, guest auth without posting, exact notification target and search return. The additional live native UI journey also passed against the configured site. Across these two UI batches, eight distinct journeys passed and two failed; this is aggregated evidence, not an all-green run. No live posting, bookmarking, Like, notification mark-read or deletion was performed. Live read batches were separated to limit request bursts.

The visibility probe's first run had an invalid synthetic response missing required `page`; that run did not establish visibility behavior. After correcting the probe payload, both diagnostic probes passed. The normal production test source was restored byte-for-byte. No diagnostic probe tests were left in the app targets; the concurrently added catalogue test was preserved.

[Sanitized run summaries](test-runs.json) retain results, failures, device and exact local `.xcresult` names, including the invalid initial probe. Full bundles remain under the machine's XcodeBuildMCP workspace `result-bundles/`. The Release build log is `build_sim_2026-10-06T22-13-03-049Z_pid7214_6b27f35f.log` in that workspace's `logs/` directory.

## Concurrent working-tree coverage

Composer toolbar/catalogue, English/Arabic strings and a catalogue UI test changed externally during the audit. The edits were preserved and fingerprinted in [source snapshot](concurrent-source-snapshot.json). Baseline results apply to starting commit `a93cb62`; newer layout checks apply to that fingerprinted working tree. The initial four-test layout batch suffered test-runner termination and Mach IPC failure and supplies no functional acceptance evidence. The catalogue retry failed as described above. The remaining three-test layout batch compiled successfully, but runtime overlaps a separate XcodeBuildMCP process using the same Simulator. The stalled waiting call was terminated without a completed functional result; no pass or app failure is inferred. Its log is `test_sim_2026-10-06T22-20-53-088Z_pid7214_31dd9850.log`. Release compilation above applies to the starting commit; concurrent catalogue changes have Debug test-build compilation evidence. No final Release claim is made for those concurrent edits. The host also reported insufficient temporary disk space during report finalization; redundant audit screenshot exports were removed after preserving the rotation image in this report.

## Boundaries

Backend reference revision was freshly checked and remains `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Guest/member reads were freshly exercised; yesterday's approved write round trip remains historical evidence and was not repeated. This audit does not establish fresh authentication issuance, revocation/expiry on the deployed site, restricted-group or pending-review matrices, uploads/secure media, member-selected theme precedence, physical-device VoiceOver/keyboard behavior, current iPad resizing, performance profiles or App Store distribution acceptance. Release simulator compilation is not a device archive or a fresh upload. See the API and release-readiness documents for the remaining gates.
