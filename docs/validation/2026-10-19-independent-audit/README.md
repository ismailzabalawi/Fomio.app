# Independent integration audit — 2026-10-19

Audited the latest Claude Desktop session, “Fomio native notifications implementation,” and its integrated code at `eef6b2f452efc3820fb69677195f5dcff4759b70`, branch `claude/fomio-release-integration`, worktree `.claude/worktrees/fomio-release-integration`. This includes build 7 baseline adoption, notifications (`afeea60`) and the composer transition fix (`eef6b2f`). No implementation or release changes were made by this audit. The integration worktree was left untouched while Claude ran tests.

## Findings

### [P2] Reject an inbox refresh whose snapshot predates acknowledgment

Location: integration `Fomio/Features/NotificationStore.swift:96–102`.

The cursor epoch added for the earlier audit protects `loadMore`, but `refresh` checks only the account generation. A refresh can snapshot the unread history, suspend, then return after acknowledgment has successfully removed a row and shifted the cursor. It unconditionally merges its stale unread item and restores its ID. Its cursor reconciliation then also restores the wrong offset.

Deterministic reproduction using the unchanged production store and notification models: unread IDs 8…1, page size two; suspend refresh after taking its server snapshot; successfully acknowledge 8; deliver the old snapshot; request another page. Output:

```text
After successful acknowledgment: ["7:false"]
After older refresh completes: ["8:false", "7:false"] next: Optional(2)
Next page IDs: [8, 7, 5, 4] server ID8 read: true
```

ID 8 reappears unread and unread ID 6 is skipped. This can occur when a manual/foreground refresh overlaps destination acknowledgment, without an account change. Validate a mutation/cursor revision for refresh too, and restart or re-fetch safely after a conflict. Add the suspended-refresh/acknowledgment regression, including All/Unread interactions. Saved source harness: `probes/Race.swift`, with minimal dependencies and the implementation's extracted fixture. It compiles against production `Notifications.swift` and `NotificationStore.swift`; it does not modify them or send live requests.

### [P2] Preserve multi-author grouped notifications when one member is ignored

Location: integration `Fomio/Domain/Notifications.swift:65–66`, consumed by `Fomio/Features/NotificationViews.swift:106`.

`actor` correctly returns nil for grouped replies, but `filterNames` still includes `originalUsername`. Ignoring that one member hides the entire grouped notification, including replies from other members. The existing test says grouped rows have no ignored actor but does not put the grouped row's original author in the ignored list.

The same production-model probe constructs a three-reply bucket and ignores its original member:

```text
Grouped actor: nil hidden by ignoring original member: true
```

Backend source `app/services/post_alerter.rb:632–676` retains `original_username` from the incoming post while replacing `display_username` with localized “N replies” and counting the bucket. That one original username is not proof that all replies belong to the ignored person. Preserve grouped rows unless there is sufficient member-level evidence to filter the entire aggregate; test a mixed-author bucket after the original member is ignored.

## Earlier audit and regression evidence

- Recompiled and ran the earlier unchanged three probes against this integrated production store. All three original sequential failure cases now behave correctly: acknowledgment removes ID 8 from Unread and next page includes 6; an empty inaccessible refresh removes cached titles; missing ID 8 during recheck stays unread/unknown. The new finding is the overlapping refresh case that those probes and the added in-flight-page test do not cover.
- The fourth earlier fix is present: `DiscussionState.requiredContentReady` gates grouped thread acknowledgment on loaded children without a child error; the view rechecks readiness after retry. The regression test exercises parent success, failed child request, then successful retry. This pass checked source and test evidence rather than independently rerunning that UI journey.
- Claude's notification validation document records all eight original UI failures passing after fixes, with baseline comparisons and root-cause artifacts. It records a final notifications-branch full suite with 179 tests, seven skipped, one composer failure. That composer failure was subsequently investigated as a real transition/focus race in a separate session and its fix is now integrated. The helper waits for the navigation transition after the prior fixed delay; its documentation records fresh-simulator controls and six passing composer journeys. No temporary diagnostic switch/logging was found in the final helper.
- During this audit the integration log reported 129 unit/contract tests executed, four skipped, zero failures, including all 23 notification tests. UI checks were still running. The command selects notification/feed UI and several composer/auth journeys; it is not the entire UI target. No final all-green integrated full-suite result was available at audit time. No second simulator run was launched concurrently by this audit.
- The integration tree was clean and local `origin/main` remained at `4f0111e` when checked. Claude's visible session said nothing had been pushed and build 8 would be uploaded after verification. This audit does not certify a remote push, branch cleanup, App Store upload or App Review submission.

## Contract and acceptance limits

Backend reference freshly rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, unchanged. `NotificationsController#index:81–98` still filters unread before raw count/offset/limit, then filters inaccessible topics and disabled badges. No deployed revision equivalence, member request, notification mutation or backend change was performed. The source verification and unresolved deployed assumptions remain as recorded in the integration API reference.

Live APNs/relay delivery is explicitly unavailable, not implemented by these inbox changes. Expired-key tap handling and tests now exist, but deployed revoked-key behavior remains unverified. iPad/physical-device acceptance for the composer transition fix and complete accessibility/push acceptance remain open in the implementation's validation documents.

The four original fixes have materially improved the implementation, but the two findings above should be corrected and covered before accepting this integration.
