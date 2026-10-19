# Independent notifications audit — 2026-10-18

Reviewed the working changes on `claude/fomio-notifications`, based at `b62aef5`, against the approved notification IA, exported design, current source and existing test artifacts. The staged release/safety baseline was excluded from notification findings. No app or backend code was changed in this audit.

## Findings

1. **[P2] Reconcile the unread cursor after a successful acknowledgment.** `Fomio/Features/NotificationStore.swift:149` updates the item but leaves its ID in the Unread feed and leaves that feed's raw offset unchanged. Discourse filters `read: false` before applying offset. With unread IDs 8…1 and a two-row window, acknowledging 8 leaves the client showing `[8(read), 7]`; the next request at offset 2 returns `[5, 4]`, permanently skipping unread ID 6 until a reset. Invalidate/reload or correctly reconcile the unread feed and cursor when acknowledgment succeeds, including acknowledgment from the All feed. Cover partially loaded feeds and an in-flight page request.

2. **[P2] Do not retain the entire old feed when refresh has no overlapping IDs.** `NotificationStore.swift:97–106` assumes every old row is older when no returned ID matches. A successful first-window refresh that now excludes inaccessible notifications returns an empty array while retaining a nonzero raw total/next offset. The code keeps all old restricted topic titles and reports successful refresh. The same merge also retains replaced IDs when an entire first window changes. Restart the authoritative history window when its coverage cannot be established, rather than treating absent IDs as verified older rows.

3. **[P2] Do not infer a successful read from absence in filtered history.** `NotificationStore.swift:178` sets `read = true` after exhausting unread pages. Discourse excludes inaccessible topic notifications and disabled badge notifications after querying unread history. Therefore an unread notification can disappear without a successful mark-read write. A probe with server ID 8 still unread but newly inaccessible ends with client ID 8 read and its uncertainty cleared. Require positive read-state evidence, or retain an unknown/unavailable outcome; absence alone cannot confirm the write.

4. **[P2] Wait for grouped replies to load before acknowledging their notification.** `Fomio/App/AppState.swift:156–160` only requires a page and no top-level error. For grouped replies, `DiscussionState.swift:58–69` loads the parent then fetches children. Network failures in that child request are stored in `childErrors` (`:123–126`), while the outer load clears the top-level error. `DiscussionView.swift:74–75` then calls `displayed`, so the server notification becomes read even though the new replies failed to display. Keep acknowledgment pending until the required grouped-reply content successfully loads; add a parent-success/children-offline regression test. This finding is established by source tracing, not a simulator reproduction.

## Verification

Three independent Swift probes compiled the production `Notifications.swift` and `NotificationStore.swift` unchanged, using a minimal service adapter and the implementation's extracted `NotificationFixture`. The fixture models the verified server ordering of unread filtering, raw pagination, and inaccessible-row filtering. Dependencies, fixture and entry point are saved in `audit-probes/`. No live requests or writes were performed.

Observed output:

```text
Unread after acknowledgment: ["8:read=true", "7:read=false"]
Unread after next page: [8, 7, 5, 4] ; expected next unread ID 6, found: false
After successful refresh removes access to all targets: ["Restricted topic 8", "Restricted topic 7"] ; refreshError: nil
Recheck inaccessible unread row: server.read= false ; client.read= Optional(true) ; outcome= nil
```

To rerun from this worktree, compile the three files in `audit-probes/` with `Fomio/Domain/Notifications.swift` and `Fomio/Features/NotificationStore.swift` using `xcrun swiftc`, then execute the resulting binary. A writable module-cache path may be needed. The first sandboxed compilation could not launch Apple's Observation macro plugin; the authorized compilation outside the nested sandbox succeeded. This is a store-level reproduction, not a full UI test.

Backend reference freshly checked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. `NotificationsController#index:81–98` applies unread filtering before count/offset/limit and inaccessible/disabled-badge filtering afterward. These source contracts explain findings 1–3. Deployed revision equivalence and ordinary-member live behavior remain unverified by this audit.

Inspected Claude's `.build/notif-full-27.log`: 121 unit/contract tests executed, four skipped, zero failures; all 16 notification unit tests and nine notification UI tests passed. The full UI run executed 49 tests, three skipped, eight failures, ending `TEST FAILED`. Failures concern feed appearance/anchor and composer journeys. Their cause and relationship to this change are unresolved; they cannot be classified as pre-existing or harmless from this evidence. The full simulator suite was not rerun during this audit.

Inspected supplied narrow-phone accessibility/dark and iPad settings captures: the native tab labels remain legible and iPad wording uses “This iPad”/“on this iPad.” This is screenshot evidence only, not complete interactive accessibility acceptance.

## Remaining acceptance gates

- Real APNs/relay enrollment and delivery are explicitly unavailable in live mode; fixtures simulate them. This is a disclosed external dependency, so inbox implementation does not establish working public push delivery.
- Expired-key tap recovery has no demonstrated acceptance evidence. The incoming-tap path checks a stored username, while actual 401 errors surface through generic load errors. The signed-out fixture test does not establish expiration recovery.
- The implementation-status document links `validation/2026-10-18-notifications/README.md`, which was absent at audit time. This audit does not replace the missing final validation summary.

The four findings need correction and regression coverage before accepting the notification implementation.
