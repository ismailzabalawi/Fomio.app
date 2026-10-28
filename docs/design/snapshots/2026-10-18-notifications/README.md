# Notifications design snapshot — 2026-10-18

Approved Claude Design project: [Fomio design system planning](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2FNotifications+-+Native+IA+2026-10-18.dc.html). Read on 2026-10-18 during native implementation through the claude.ai design file reader (read-only `list_files` / `get_file`; nothing was written to the project). The built-in browser was not signed in to claude.ai, so the board was not rendered live in this session.

## Source files

| File | Status | SHA-256 |
| --- | --- | --- |
| `source/FmNotifDevice.dc.html` (device component: inbox, rows, destinations, settings, setup states, push/composer cases, final narrow-tab and device-wording corrections) | Exported verbatim | `08901ab229918fe9c1575f0ca5c1911ae27c4da00e83ed97e288f34ec982fbc1` |
| `source/support.js` (generated dc runtime the mockups import) | Exported verbatim | `8fe7df74405f3c55f49b7249c74ea1397e65d07dea2b1bd3b4a489bec2e28cbe` |
| `mockups/Notifications - Native IA 2026-10-18.dc.html` (board: Overview, Prototype, Cases NT01–NT12, Handoff) | Read in full; not stored here (the reader returned it inline only). The cloud file stays the editable reference | — |

Captures in this folder (`inbox-light.jpg`, `narrow-tabs-fixed.jpg`, `bottom-clearance-fixed.jpg`, `ipad-wording-fixed.jpg`) are the reviewed browser renders; `narrow-dark-ax2.jpg` predates the tab correction.

## How native implementation used it

Copy (row verbs, grouped wording, acknowledgment states, empty/footer text, settings statuses, explanation sheet, iPhone/iOS vs iPad/iPadOS wording, mismatch and composer-protection text), state model (`AckState`, setup statuses) and the board's Handoff rules were carried into SwiftUI. The mock's custom HTML tab bar is a browser stand-in: native uses the system `TabView` with `sidebarAdaptable`, as the Handoff itself specifies. Fixture people/topics differ from the mock's fictional seed; the native fixture mirrors its cases (exact, grouped branch, grouped topic, unavailable, unsupported with/without web fallback, filtered empty unread batch, failure toggles).

Browser rendering is design evidence only. It does not establish native Dynamic Type, VoiceOver, materials, permission prompts or delivery.
