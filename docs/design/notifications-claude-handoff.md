# Notifications Claude Design handoff

Requested: 2026-10-18. Source: [Notifications IA and integration map](../notifications-ia.md). Destination: existing [Fomio design system planning](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2) project in Claude Design.

## Submitted brief

Create a separate **Notifications - Native IA 2026-10-18** presentation board, working prototype, states/case library and native component handoff. Preserve historical Home/category/topic/composer files. Use the bound design system and latest compact Fomio style, native iOS/iPadOS 26+ direction, system sans body, readable flat content, glass for functional navigation, illustrative Discourse theme palettes and independent category identity. Recent unapproved branding adaptations are not an accepted replacement direction.

The brief carries source-backed distinctions between history/recent pagination, row read and seen state, exact-ID versus bulk acknowledgment, exact-post versus consolidated parent-branch destinations, inbox versus push delivery, and current native gaps. It requests a coherent proposed community inbox that retains unsupported rows rather than claiming an All view while dropping types. Source facts remain distinct from proposed client behavior and deployed verification.

NT01–NT12 cover guest/auth, populated inbox, empty/filter continuation, loading/offline/refresh/pagination recovery, exact target, grouped replies, unavailable/unsupported destinations, read failure/reconciliation, device settings, contextual permission/setup states, incoming push/auth/account/composer protection, and other-client/account/token changes. Product UI must not expose relay/API jargon or treat OS consent as successful setup/delivery. All OS permission and delivery interactions are simulations, without real browser prompts or live member actions.

The brief requests curated overview frames and a genuinely navigable prototype, with reviewer controls and coverage/source notes outside product chrome. Variants include light/dark, Purple/Teal/default illustrative palettes, 320/390pt, accessibility text approximation, iPad, mixed Arabic/English/RTL and reduced motion. Key click-through journeys and actual checks/limitations must be reported separately.

## Apple reference

Used the Apple HIG skill and current official indexed content for [Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications?changes=_4) and [Managing notifications](https://developer.apple.com/design/human-interface-guidelines/managing-notifications?changes=_5). The brief applies contextual consent, relevant content and respect for system settings/Focus. Browser simulations cannot verify native permission presentation, Dynamic Type, VoiceOver, materials or APNs delivery.

## Verification status

Created and independently opened [Notifications - Native IA 2026-10-18](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2FNotifications+-+Native+IA+2026-10-18.dc.html). Claude reports two new files: that board and `mockups/FmNotifDevice.dc.html`, with historical Home/category/topic/composer files preserved. The board contains Overview (six frames), Prototype, Cases NT01–NT12 with subcases, and Handoff. The final view is the populated inbox, Purple/light at 390pt. No native app or backend code changed in this task.

Independent browser checks:

- Exact reply opened topic context and post #15, then confirmed mark-read for notification 5011; badge 7 → 6. Back returned to inbox.
- Grouped notification 5010 opened parent post #4 and three new replies (#21–23), with explicit branch context. Back returned to inbox; acknowledgment reconciled the badge.
- Unavailable notification 5006 showed a recovery explanation, remained unread and retained the badge. Back retained inbox offset 449 in the reviewer readout.
- A failed mention acknowledgment retained unread state and badge 5; Try again confirmed read and reconciled badge 4.
- Explicit opt-in opened an explanation, then a simulated OS prompt. Allow left registration pending; the injected setup failure showed that permission was allowed but delivery setup incomplete. Retry reached the simulated On state.
- The requested settings copy correction was visibly verified: “You can still check activity in your inbox when alerts are off.” It no longer claims the paginated/offline list is always complete.
- Populated light, Teal dark at 320pt with AX2 approximation, and Teal dark iPad with RTL layout were visually inspected. The narrow Communities tab label still truncates and needs refinement. iPad settings still say “This iPhone”; device-specific wording needs correction. These are review findings, not native acceptance failures.

Claude separately reports exact-reply scroll retention, grouped Back, unavailable/offline, failed/unknown read recovery, Not now/denied/Settings setup, expired-session and other-account push handling, composer preservation/save-and-open, empty unread intermediate page, duplicate push suppression, new/other-client read/reconnect, next-page failure retry and sign-out clearing. These are Claude-reported browser simulations, not independently repeated by Codex beyond the subset above. Claude's final design review found 38pt All/Unread controls and reports raising them to 44pt; it did not rerun the background review after that change.

Still unverified: independent full NT01–NT12 regression, cold-start push directly, narrow/RTL Back retention, setup-renewal settings status, every overlay with keyboard, exhaustive targets/contrast, native Dynamic Type/VoiceOver/materials, actual permission/Settings interactions, live Discourse reads/writes/realtime and physical-device push. Unsupported notifications without a valid web destination have no explicit per-row dismissal in this slice; that product decision remains open. Browser rendering is design evidence only.

Captures: [light inbox](snapshots/2026-10-18-notifications/inbox-light.jpg), [narrow dark accessibility approximation](snapshots/2026-10-18-notifications/narrow-dark-ax2.jpg), at 75% Claude canvas zoom. No source export was downloaded; cloud files remain the editable mockup reference.

## Narrow tabs and device wording correction — 2026-10-18

User approved the direction and requested these two remaining mockup fixes before native notification implementation. Claude modified only `mockups/FmNotifDevice.dc.html` and the Notifications board/handoff. The earlier truncation and “This iPhone” findings above are resolved for the checked browser variants; historical captures remain unchanged.

The tab layout now allocates width by full label, allows wrapping, uses a taller bar at AX2 and reserves bottom clearance. Labels retain full accessible names and the notification count. Claude reports a 62pt default / 72pt AX2 bar, 13pt narrow AX2 labels and 14pt 390pt AX2 labels, with icons growing at AX2. iPad retains the sidebar. Device/OS wording derives from the selected device across settings, explanations, setup/recovery and related mock notices.

Independent checks on the final rendered files:

- 320pt default, 390pt default, 390pt AX2, and 320pt AX2 dark/RTL: all four complete tab names remained exposed, button scroll width did not exceed client width, and every target was at least 44pt wide. Default targets measured 51pt high; AX2 targets 61pt high. The screenshot at 320pt AX2 visibly confirms full Communities and Notifications labels. Dimensions here are unscaled layout dimensions; canvas screenshots use 75% zoom.
- Keyboard focus/End reached the final loaded page. The last notification and “That's everything” message were visibly above the enlarged tab bar. Earlier auto-pagination was exercised along this path; this was not a full notification behavior regression.
- iPad settings showed “This iPad”; the opt-in explanation used “this iPad” and “iPadOS Settings.” Permission allowed → registering → injected setup failure → retry → ready all retained correct wording. Renewal showed “Refreshing this iPad’s alert setup.”
- Reset permission → denied showed “Open iPadOS Settings”; opening it displayed the simulated iPadOS Settings screen and “Fomio can’t show alerts on this iPad.” Phone settings still showed “This iPhone” after switching back.

Claude additionally reports measuring 320pt AX2 across light/dark and LTR/RTL and updating the board's NT02/NT09/NT10 cases and Handoff notes. It identified an existing RTL time-order issue (“Unread min 12”); that unrelated localization issue remains recorded for implementation. Native Dynamic Type, VoiceOver and system tab behavior still require native validation. No app/backend code changed and no real permission or delivery operation occurred.

Evidence: [corrected narrow tabs](snapshots/2026-10-18-notifications/narrow-tabs-fixed.jpg), [final-row clearance](snapshots/2026-10-18-notifications/bottom-clearance-fixed.jpg), [corrected iPad setup wording](snapshots/2026-10-18-notifications/ipad-wording-fixed.jpg). Final prototype: populated inbox, 320pt AX2, light/LTR, test failure injection cleared.
