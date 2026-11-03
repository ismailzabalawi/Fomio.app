# Fomio iPhone Duo UI/UX guideline

Reviewed: 2026-10-24 (Asia/Amman). Status: design guidance and acceptance criteria; this review changes documentation only.

## Purpose and authority

Make browsing and writing feel continuous as available space changes. Preserve Fomio's community → discussion → reply hierarchy and the current native visual identity. Discourse continues to determine data, permissions and posting outcomes.

Apple platform behavior below was checked against live documentation and video transcripts. Fomio requirements are product-specific recommendations grounded in the existing [design handoff](mvp-design-handoff.md), [adaptive navigation contract](../adaptive-navigation-ia-api-map.md) and [Duo readiness record](../iphone-duo-readiness.md). That readiness record owns implementation evidence and unresolved native checks; this guide does not close those gates.

## Platform baseline

Apple recommends a resizable interface with consistent functionality and hierarchy. Standard split views, sheets and menus accommodate reserved regions; custom interactive content needs equivalent consideration. The folding region and camera regions can change usable space. Avoid large, unnecessary rearrangements during a fold. [Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

Most Duo configurations use vertical system bars; the inner display in portrait uses horizontal bars. In multitasking the control edge can change, and RTL does not simply mirror the hardware-aligned bar. Design against the supplied safe area. [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/).

Build SDK and deployment target are separate decisions. Apple's preparation page distinguishes compatibility with the iOS 26 SDK, dynamic resizing with 27, and full-display/vertical-bar adaptation with 27.1+. Retain Fomio's iOS 26 minimum unless a separate product decision changes it. Check individual new API availability before adoption. [Preparation checklist](https://developer.apple.com/iphone-duo/prepare/).

## Layout contract for Fomio

| Available space | Recommended composition | Continuity requirement |
| --- | --- | --- |
| Narrow, including an outer display or multitasking window | One active pane with native Back and access to app destinations | Keep the selected discussion or exact reply visible when collapsing |
| Enough usable width for list and reader | Discussion list beside selected discussion; community scope and destination tabs remain attached to the list | Preserve the same scope, list selection and reply branch. Tabs sit at the bottom of the list column, never across both panes or the fold |
| Enough usable width for sidebar, list and reader | Existing community sidebar plus list and discussion | Sidebar destinations replace hidden tabs with equivalent labels, selection and unread status |
| Large text or reduced height | Reduce pane count when content no longer fits; permit vertical scrolling and tool overflow | Keep essential actions reachable without reducing text or touch targets |

These are available-space states, not device identities. Existing recorded thresholds (720/1080pt, adjusted for text size) are implementation details requiring Duo acceptance, not Apple-prescribed breakpoints. Evaluate the usable pane after system bars and reserved regions. Width alone cannot establish that a three-pane arrangement works around a partial fold.

Keep the discussion reading measure bounded by the existing 620pt maximum. Center it within its usable content pane. Expanding the window should expose useful context rather than increase prose line length indefinitely. Keep feed media meaningful when aspect ratios change; avoid cropping away the subject or text embedded in an image.

## Navigation and action placement

Use native navigation containers for app bars. Supply symbols and titles so the system can choose a suitable bar or overflow representation. Keep related actions grouped, give frequent/status-bearing actions visibility priority, and consolidate overflow in the system menu. Keyboard accessory controls stay with the keyboard. [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/).

Fomio action priorities:

| Surface | Preserve direct access first | Secondary access |
| --- | --- | --- |
| Browsing | Back, app destinations, notification unread status, community scope | Create and feed options remain discoverable through overflow when necessary |
| Discussion | Back/Close, Reply and reading context | Like, Save, Share and permitted report actions retain stable contextual access |
| Composer | Close, Post with its validation/submission state, writing area | Undo/Redo and frequently used formatting remain reachable; less frequent insertion tools can overflow |
| Search/chooser | Cancel/Back, query/filter, current scope and result selection | Clear, hierarchy expansion and Retry remain reachable in short windows |

Keep community selection, feed filtering and list search near the list they affect. Discussion actions belong to the discussion. Do not move every custom content control into a global side rail. The existing sidebar/tab handoff needs explicit review for destination parity, unread badges and focus continuity.

## Writing and sheets

Folding is a layout event, not an editor exit. Preserve title, body/source, destination, rich/Markdown mode, selection, caret, focus, undo manager and staged photos. Never reopen a second editor merely because a size class changed.

The custom formatting bar must remain clear of docked or floating keyboards and changing safe areas. Verify an actual typed character before and after each transition without refocusing. Post must remain distinguishable from draft saving; validation, upload failure, pending review and an unconfirmed submission require their existing distinct recovery states. Resizing must not retry a write.

Let native sheet presentation adapt. Apple documents different outer/inner sheet bar arrangements and automatic fold avoidance; do not force one screenshot's geometry onto every presentation. [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/).

Test community chooser, sign-in, photo picker, report and Keep/Discard with the keyboard visible and a short viewport. Long forms must scroll to their final action. Authentication must return to the originating intent and window without posting automatically.

## Visual design and accessibility

Retain Fomio's purple accents, system semantic typography and flat reading surfaces. Use Liquid Glass for functional navigation/control surfaces as established in the handoff. Resizing must not shrink font sizes to keep a layout intact.

Keep at least 44pt equivalent interactive targets per Fomio's existing design baseline. Permit long community names, discussion titles and translated action names to wrap. Test Arabic and mixed-direction text, accessibility text sizes, dark appearance, Increase Contrast, Reduce Transparency and Reduce Motion. Maintain meaningful accessibility labels and selection/unread announcements as destinations move between sidebar and tabs. VoiceOver focus should remain on the user's task after adaptation.

## Required design handoff and acceptance

Produce an annotated screen set showing the same selected discussion and the same draft across narrow, expanded, partially folded, portrait inner-display and multitasking layouts. Include keyboard-visible, overflow-open, accessibility-text and Arabic examples. Mark usable bounds, primary actions, overflow contents and expected focus/reading anchors.

| Native journey | Pass condition |
| --- | --- |
| Read → unfold → refold | Same topic/post anchor, expanded branches and scope; no reset to feed top |
| Search/choose community → resize | Query, hierarchy expansion and selection survive; Cancel and Retry remain usable |
| Reply → resize with keyboard | Exact writing and photos retained; direct typing, Undo and Redo work at every tested width |
| Sidebar ↔ tabs | All destinations and unread status agree; no duplicated navigation or lost path |
| Partial fold, both multitasking sides | Important controls avoid reserved regions; menus/sheets are usable on each side |
| Authorization/background/write in progress | Correct return intent and draft survive; no duplicate submission |
| Large text/Arabic/VoiceOver | Reachable actions, readable content and coherent focus order through transitions |

Record runtime, SDK, actual window bounds, text setting, pose, screenshots and observed result. Test continuous resizing and transitions in both directions. Device Hub/resizable simulator and iPhone Mirroring can expose layout issues; Apple's preferred full-experience check is the Duo simulator. Physical-device input remains a separate acceptance step. [Preparation checklist](https://developer.apple.com/iphone-duo/prepare/).

## Current Fomio priorities

The existing readiness record reports focused reply, photo/draft and keyboard continuity passes. It still leaves the full adaptive reading transition matrix, regular-width More-menu history reachability, broader accessibility traversal and secondary presentations open. These are recorded historical results, not tests rerun on 24 October.

1. Validate the custom composer toolbar and Undo/Redo at every width with the keyboard visible.
2. Validate pane transitions, sidebar/tab parity and exact-post reading continuity around reserved regions.
3. Review existing custom overflow against the system overflow guidance before proposing a native change.
4. Complete short-window sheets, Arabic/large-text and VoiceOver transition acceptance.

No backend contracts were established or changed by this review. Consult the API reference and recheck the backend revision when later implementation depends on a Discourse contract.
