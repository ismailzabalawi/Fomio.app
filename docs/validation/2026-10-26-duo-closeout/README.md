# Duo continuation — 26 October 2026

Current source starts at `8e2a2487c2e6568e8f39ec57de9f016d150c8a53`. Xcode 27.1 (`27A9275`), iPhone Duo / iOS 27.1, simulator `FD81C641-B4C2-4E69-9459-867DE508F033`. Fixture composer checks plus user-completed live authorization; no live content writes. This is a scoped continuation, not complete device or release certification.

## Native Computer observations

Built and launched the current app with `--fixture --preset reply`. Used Device Hub through Computer. The embedded app accessibility tree was unavailable during resize mode, so input used inspected screenshots and native coordinate clicks. Raising the Device Hub window was necessary for keyboard input into its dimension fields; an AX value change alone reverted on Return. A transient `noWindowsAvailable`/ScreenCaptureKit failure recovered after raising the window; it does not establish a locked Mac.

Both width cycles used Device Hub's displayed **466 × 678 → 1000 × 678 → 466 × 678** dimensions. These are resize-mode journeys, not newly measured native window traits or a hardware fold. The same reply stayed open without relaunching or tapping the body after each transition. Editor/undo-manager pointer identity and exact UTF-8 bytes were not instrumented in this pass.

| Journey | Observed result | Captures |
| --- | --- | --- |
| Rich-text history at expanded width | A compact onscreen `Q` was autocorrected to `A` when the menu opened; compact Undo restored `Q`. After expansion, More opened and Redo restored `A`; Undo restored `Q`. This is actual history execution, including the system correction, not a `canUndo` flag. | `regular-history-menu.png`, `regular-redo-A.png`, `regular-undo-Q.png` |
| New expanded-width input | Without refocusing, an onscreen `q` made `Qq`; native More → Undo restored `Q`. Keyboard remained visible and the bar stayed above it. | `regular-typed-Qq.png`, `regular-new-typing-undone.png` |
| History after compact return | Pending Redo restored `Qq`; Undo restored `Q`. Continued onscreen input again made `Qq`. Selecting the literal keyboard suggestion then added a trailing space. | `compact-return-redo-Qq.png`, `compact-return-undo-Q.png`, `compact-return-continued-typing.png` |
| Multiline Markdown | Switched the same reply to Markdown, entered two line breaks and `Q` on the next paragraph. Expansion retained the visible paragraphs, Markdown mode, keyboard and caret. Onscreen `q` changed the final paragraph to `Qq`; Undo restored its `Q`. After compact return, Redo restored `Qq`. | `markdown-compact-multiline.png`, `markdown-regular-retained.png`, `markdown-regular-typed.png`, `markdown-regular-undo.png`, `markdown-compact-return.png`, `markdown-compact-redo.png` |
| Keep/reopen | Close exposed all three Keep draft/Discard/Keep editing actions. Keep closed the sheet; the discussion's Reply action reopened the two visible paragraphs. Reopening started in rich text with keyboard down. | `keep-draft-confirmation.png`; reopen observed in Computer transcript |

These observations resolve the earlier inability to demonstrate regular-width native More-menu interaction for this simple text fixture. They do not turn the old failed XCTest journeys into passes, and they do not complete the exact automated `Trait draft` journey, source-marker/formatting/block/photo history, or every width/keyboard configuration. In particular, the last newly typed compact-return character was not separately undone in this manual sequence. Some compact-return captures show the scrolled header/Markdown label partly outside the viewport; complete header reachability is not inferred from those captures.

## Automated verification and configuration

The initial combined run executed **177 passing unit/contract cases, four opt-in live skips**, then failed before UI cases could launch. The runner's packaged identifier was `.xctrunner`: neither test target had an explicit `PRODUCT_BUNDLE_IDENTIFIER`. Added `com.fomio.mobile.tests` and `com.fomio.mobile.uitests` in `project.yml` and both configurations of the committed project. XcodeGen's unrelated regeneration changes were removed, preserving existing project/scheme settings.

The corrected packaged runner identifier is `com.fomio.mobile.uitests.xctrunner`. MCP retries, including explicit runner installation, still failed registration/launch with `Unknown application display identifier`. A direct fresh-DerivedData Xcode test build reproduced the registration failure. The sandbox-only direct attempt could not connect to CoreSimulator; the subsequent permitted native-service run reached the runner failure. None is a UI acceptance pass. Original MCP result paths/counts/failures are in [automated-results.json](automated-results.json).

After restarting only the Duo simulator through Device Hub (no erase), the final combined regression **passed: 177 unit/contract cases plus four UI cases; four opt-in live cases skipped, zero failures**. The passing UI journeys cover More-menu Undo/Redo refresh, failed-photo Keep/resume, guest sign-in without posting, and native caret/formatting through source-mode switching. The MCP request timed out while Xcode continued; the completed xcresult, not that timeout, establishes the result. See [final-regression-summary.json](final-regression-summary.json). The machine-local result is `test_sim_2026-10-26T06-07-47-355Z_pid43453_be22b4df.xcresult` under the XcodeBuildMCP workspace result-bundles folder. This supersedes the runner launch blocker, while preserving the original failed runs above.

## Live authorization and session continuity

Launched the final app with `--live`. The user completed the configured meta.fomio.app browser sign-in and reviewed/approved authorization themselves, returning to a signed-in Me screen on Closed Duo. Saved and Drafts both displayed zero. Open retained the same signed-in account; backgrounding through Home, closing the device while backgrounded, and reopening Fomio retained the same Me screen and session. No credential, callback URL, or private response was copied into this packet. This checks completed-session continuity; pending browser authorization during a fold/resize remains unverified. No post, upload, bookmark, reaction, or account mutation was performed.

The explicitly enabled read-only live test `LiveDiscourseTests/testStoredMemberReadPermissionsSavedAndNotifications` passed: one passed, zero failed/skipped (`f9438905`). It checks current identity, categories/theme/profile, Saved, Notifications, safety/Ignore availability, current report options and account-deletion eligibility. It does not prove every permission boundary or non-staff role. See [live-read-result.json](live-read-result.json).

## Capability correction

`FeedView` now reads `EnvironmentValues.supportsMultipleWindows` for the New window command instead of checking `.pad`. The system determines availability, including future supported configurations; this change does not promise that Duo supports a second window. Apple's [API documentation](https://developer.apple.com/documentation/swiftui/environmentvalues/supportsmultiplewindows) describes this value as the condition for using `openWindow`. Its [window guidance](https://developer.apple.com/design/human-interface-guidelines/windows) recommends an optional new-window command and fluid resizing. The final build and regression passed. The live Duo accessibility tree exposed New window, establishing that the command can be offered on this simulator. Opening and independently navigating a second native window remains unverified.

## Remaining acceptance boundaries

- Finish the full exact-value history journey at both widths and after return; include Markdown syntax, formatting/block/photo operations, long text and title focus.
- Check final-source feed appearances/pagination/crops, exact reply/expanded branches, sidebar/tab unread parity, short secondary sheets, partial fold and multitasking sides.
- Complete VoiceOver swipe/rotor traversal and focus continuity; retain existing failed predictive accessibility audits as failures alongside functional evidence.
- Completed live authorization and subsequent fold/background/return retain the member session. Pending browser authorization through resize/background/return still needs a separate interactive attempt. Real uploads/in-flight submissions require a suitable account and explicitly scoped test data; fixture success does not establish them.
- Physical device and TestFlight input/Photos/accessibility acceptance remain separate.

The newer [adaptive acceptance audit](../2026-10-20-adaptive-native/acceptance-audit.md) already records qualified five-layout and targeted accessibility successes, plus later-source limitations. Reuse those within their stated scope rather than treating the older readiness matrix as entirely untouched.
