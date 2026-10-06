# Category and topic Claude Design handoff

Requested: 2026-10-06. Source: [focused category/topic IA](../category-topic-ia.md). Destination: existing [Fomio design system planning](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2) project in Claude Design.

## Brief submitted

Create a new named category/subcategory/topic screen pack and interactive prototype, without overwriting historical composer files. Native SwiftUI iOS/iPadOS 26+ direction takes precedence over the project's older Expo/web assumptions. This is design work; app/backend changes are outside this task.

Use the Fomio purple/white and AMOLED palette, system sans typography, flat readable content, native-style navigation/menus/sheets and adaptive iPad sidebar. Four primary destinations: Home, Communities, Notifications, Me. Search is a utility; Create is contextual. Represent Liquid Glass in the functional layer only. All taxonomy, topics and users in the mockups are illustrative.

The submitted brief carries the IA's recursive category identity, aggregate/direct-only feed distinction, permission independence, nested-root/branch paging, bounded indentation, exact-reply/context navigation, placeholders and preserved return state. Category administration, chat, private messages, ranking/votes, tracking controls, editing, staff tools and AI are excluded. Existing composer is a handoff destination, not a requested redesign.

Required screen families: CA01 directory including deeper descendants/filter/partial/failure; CA02 parent including scope/empty/read-only/pagination; CA03 leaf/deeper descendant; CA04 About; TO01 topic including nesting/no-replies/closed/archived/deleted-ancestor/branch-error/pagination; TO02 exact reply/focused/truncated/unavailable. Include guest intent, contextual creation, pending approval and unconfirmed outcome. Reviewer state controls and source annotations must live outside product chrome.

Required journeys: directory → parent → child → deeper child → topic → expand branch → focused thread → all replies → Back; directory filtering and retained return; exact target from search/notifications; About; simulated Like/Save/Share; guest authorization intent; composer destination inheritance. Representative light/dark, large text, narrow and iPad variants were requested, including long paths/titles and mixed Arabic/English content.

## Apple reference use

Consulted official Apple search excerpts for [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) and [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass). These support separating controls/navigation from content, larger text, generous iOS touch targets and language-aware reflow.

Full HIG page reads returned JavaScript shells through the web reader; a browser accessibility-page attempt also did not expose article content and its temporary tab became unavailable. The brief uses the established project requirements plus the official indexed excerpts. No comprehensive current HIG compliance claim is made.

## Verification status

The brief was submitted through the existing Claude Design browser UI. The first turn read project references but ended without an artifact. A shorter retry asked Claude to write the core working prototype first, retaining the original IA and state requirements.

Final artifact: [Category and Topic - Native IA 2026-10-06](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2FCategory+and+Topic+-+Native+IA+2026-10-06.dc.html). Claude reported that the initial ampersand filename rendered blank and renamed the new artifact using “and”; the resulting file was independently opened and rendered. Historical composer files remain references rather than the output of this task.

The pack has a review index with CA01–CA04, TO01–TO02, FL and VR cases, one active phone/iPad frame, reviewer controls outside product chrome, annotations and a coverage table. It includes recursive category navigation, aggregate/direct scope, read-only/empty/partial/error states, nested/focused/exact-reply views, guest intent and outcome handoffs. Optional direct-only scope is marked proposed. Topic photo content is a labeled placeholder; this is not a final photo asset handoff.

Independent browser checks completed:

- Parent Bicycles shows “Includes subcommunities” and actual child-category labels. Opening Wheel building then Hub servicing retains the full ancestor path. New discussion inherits Hub servicing exactly; closing it returns to that category. Back returns to Wheel building.
- Opening the wheel discussion, Continue this thread and Show all replies preserves the same topic and returns to the full discussion with a linked-reply cue.
- The notification exact-reply case exposes linked context; Back returns to Notifications.
- Guest Reply → simulated Sign in → permission recheck opens the reply composer targeting Leo Brandt, without automatically publishing.
- Light category and AMOLED topic frames were visually inspected and captured. The 320-point/AX2 variant was inspected for wrapping title/path behavior. This is representative visual review, not an exhaustive contrast, hit-target or accessibility audit.

Claude separately reported click-through checks for the core path, guest flow, AMOLED, iPad and narrow/AX2, and fixes for long-name overlap and abbreviated Back text. Its final report explicitly leaves search/filter return, About, Like/Save/Share and composer outcomes as code-reviewed rather than independently clicked. The notification return listed above adds independent evidence for that specific journey only. A background Claude review was mentioned but its completion was not observed; do not count it as passing evidence.

Evidence: [light category](snapshots/2026-10-06-category-topic/category-review.jpg), [AMOLED topic](snapshots/2026-10-06-category-topic/topic-amoled-review.jpg). At the original narrow Claude canvas width the review index stacks above the device; the native product frame is distinct from that reviewer layout. Captures use the canvas's 75% preview zoom, not a different native text scale.

Remaining: independent search/filter/About/action/outcome journeys; exhaustive responsive/target/contrast checks; iPad resizing; real SwiftUI materials, Dynamic Type and VoiceOver; current deployment/catalog/member write verification. No app/backend code was changed and no live member action was performed.

## Elevated second direction

The user rejected the first visual direction and asked to elevate it. “Too original” was interpreted as too conventional/plain after an optional clarification received no reply. This interpretation was stated before proceeding.

New artifact: [Category and Topic - Elevated Fomio](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2FCategory+and+Topic+-+Elevated+Fomio.dc.html). Claude reports the shared device component at `mockups/FmNativeDevice.dc.html`. The earlier design remains linked for comparison.

Changes: category monograms and recursive tree connectors; compact community identity headers; title-led discussion rows with composed activity metadata; authored opening posts, styled quotes/code and bounded thread connectors. Core, depth/focus and iPad presentation boards replace the large always-visible review index. A separate working prototype and collapsed States & cases drawer retain the fixture controls and case IDs.

Independent checks in the elevated prototype: expanded Making & Repair, opened Bicycles, navigated Wheel building → Hub servicing, verified full ancestry and Back to Wheel building, opened the wheel discussion, entered Continue this thread, and returned with Show all replies. Topic identity remained 48213 with target post #14 and a linked-reply cue. Light/AMOLED core boards and the AMOLED iPad board were visually inspected. These are mocked browser checks, not native or live contract validation.

A follow-up refinement removed the large empty photo upload slot and caption from the opening post. The default fixture is now text-led; future image guidance belongs in reviewer notes. The mocked reply label now derives “Oldest first” from fixture data; annotations distinguish requested New from effective response sort. These details were confirmed in Claude's report and the rendered core board.

Claude separately reports core-flow checks, light/AMOLED/AX2/iPad visual checks, word wrapping and dark accent fixes, and a review-driven About target-height fix. Its first elevated report explicitly left guest/composer outcomes and 320/360 phones unclicked. No independent exhaustive hit-target, contrast, VoiceOver or Dynamic Type audit is claimed. Native title scaling and all deployed settings/permissions remain to be verified.

Evidence: [elevated light board](snapshots/2026-10-06-category-topic/elevated-light-board.png), [elevated AMOLED board](snapshots/2026-10-06-category-topic/elevated-amoled-board.png). Captures use 75% Claude canvas zoom with its chat sidebar collapsed. No app or backend code changed.

## Backend identity and themes refinement

The user's subsequent correction is authoritative: category identity comes from Discourse, and global accents should follow Discourse themes/color schemes. The earlier mandatory-purple and invented-category-monogram direction is superseded for this slice. Local backend HEAD was rechecked unchanged; the source feature packet and native/deployment gaps are recorded in [the API reference](../discourse-api-reference.md).

The existing elevated artifact was refined in place. Claude reports edits to `FmNativeDevice.dc.html` and the presentation board, plus new `FmCatMark.dc.html` and fictional light/dark wheel-logo fixture assets. Category fixtures now use serializer field names for style/icon/emoji/colors/descriptions/uploads. Header logo preference and native token mapping are explicitly native proposals. Backend-configured icon/emoji/square markers replace invented initials; missing or unknown assets fall back to the category square without inheriting a parent's identity.

Directory roots retain concise description excerpts; descendants use identity/name/disclosure without repeated descriptions. The category header retains its full description. Global UI colors derive from a selected illustrative scheme; category identity remains independent. Reviewer controls offer Purple, Teal, No scheme, Light/Dark and optional AMOLED surface. These are mock data, not a live site settings claim.

Independent browser checks: Purple→Teal changes buttons, links, selected tabs and quote marks while category markers remain stable. Dark uses scheme surfaces with a separate AMOLED option. Default compact tree and category header were visually inspected. Opened Bicycles→Wheel building; its header uses the fictional provided logo. Opened the wheel discussion→Continue this thread→Show all replies, retaining topic 48213 and target/highlight #14. This verifies representative mocked navigation only.

Claude separately reports light/dark core navigation, deep hierarchy, logo variants, AX2 reflow and palette checks. It left drawer tables and exact default two-line cutoff visually unconfirmed; its subsequent background review completion was not observed. Native icon resolution, full Dynamic Type/contrast/material validation, actual deployed assets/palette selection and theme CSS overrides remain pending. Native app/backend code were not changed.

Evidence: [Purple scheme](snapshots/2026-10-06-category-topic/theme-purple-board.png), [Teal scheme](snapshots/2026-10-06-category-topic/theme-teal-board.png), captured at 75% canvas zoom. Earlier screenshots above are historical and retain the superseded monogram treatment.

## Creative direction for a younger audience

The user requested more creativity and appeal to younger generations. Claude refined the elevated artifact in place, retaining backend identity and theme mapping. The brief emphasized expressive composition, typography and short interaction transitions. This direction has not been tested with audience participants; no demographic appeal claim is established.

Rendered changes: softly tinted root-group panels, larger category markers with offset shapes, expressive disclosure buttons, a larger community identity block with geometric accents, tactile child chips, stronger author blocks and reply-count capsules, accent-tinted quotes, labeled Like/Save pills and an outlined focused-reply target. Category colors still drive identity/decorative shapes; selected scheme tokens drive global actions. Rounded heading fonts have system fallbacks; native appearance remains unverified.

Claude reports edits to `mockups/FmNativeDevice.dc.html` and the elevated board's notes; browser checks covered Purple light, Teal dark, AX2 and the recursive category/thread journey. It reports short one-off transitions with Reduce Motion support, but motion was not visually confirmed. Its 320-point, iPad and Depth boards were not rechecked in this pass. Background review completion was not independently observed.

Independent checks: refreshed the canvas to load the updated shared component, inspected Purple light and Teal dark boards, navigated Bicycles→Wheel building→wheel discussion→Continue this thread→Show all replies. Topic 48213 and target/highlight #14 were preserved. Screenshots confirm representative visual changes, not exhaustive accessibility/contrast, native motion or deployed behavior.

Evidence: [creative Purple light](snapshots/2026-10-06-category-topic/creative-purple-board.png), [creative Teal dark](snapshots/2026-10-06-category-topic/creative-teal-dark-board.png). Earlier screenshots are retained as historical comparisons. No native app/backend code changed.

## Compact defaults and one subcategory level

The user approved smaller default typography/header density and confirmed that categories have only one level of subcategories (root → immediate child). This supersedes all earlier deeper-category fixture/IA recommendations. The IA maps and API reference now distinguish this user-confirmed scope from Discourse's configurable deeper-category source capability. Nested reply depth remains independent.

Claude updated `FmNativeDevice.dc.html` and the elevated board. Reported default sizes: screen titles 26pt, community name 25pt beside a 50pt marker, discussion title 22pt, topic-row title 17pt, Latest 20pt, Replies 19pt, opening-post avatar 40pt inside a 44pt target; body 17pt and replies 16pt. Header padding/description/chip gaps were tightened. Accessibility variants grow separately and reflow, with heading caps above the default; this is a browser approximation, not native Dynamic Type validation.

Fixture taxonomy now has Bicycles as a root with Wheel building, Commuting and Hub servicing as immediate children. Making & Repair is a separate root with Sewing & textiles. Subcategories have no child section/disclosure. Bicycles→Wheel building is the wheel discussion path. Core-path text, case labels, filter ancestry, composer targets and long-name variants were updated. Source order is illustrative fixture order, not popularity.

Independent checks: refreshed shared-component preview; inspected the compact default Purple light board, AX2 reflow, and Teal dark. Opened Bicycles→Hub servicing→New discussion and confirmed the exact root/child destination and own gear identity. No post was submitted. Claude separately reports root/child/topic/focused/all-replies/back and composer checks; its background review completion was not independently observed. No native app/backend code changed.

Evidence: [compact two-level board](snapshots/2026-10-06-category-topic/compact-two-level-board.png). Prior screenshots are historical and can show superseded deeper-category chains and larger defaults. Live taxonomy/settings alignment, native accessibility/materials and exhaustive visual checks remain pending.


## Native implementation — 2026-10-06

The user authorized implementation of the final compact direction. SwiftUI now uses 26pt screen titles, 25pt category headings with 50pt identity, 22pt discussion headings, 17pt topic rows, 20pt Latest and 19pt Replies, all scaled with Dynamic Type. Default OP body remains 17pt and plain-text replies 16pt. Root panels, compact children, tinted offset identity shapes, wrapping category chips, authored OP, reply-count pills, tinted quote blocks, labeled Like/Save and a focused-target outline follow the approved composition. The existing native toolbar/tab/sheet controls retain Liquid Glass; content stays flat.

Fixtures retain the app's established Woodworking/Electronics/Gardening content rather than substituting the mockup's fictional Bicycles taxonomy. Fixture category identities/colors and `--teal-theme` are explicit development examples. Live identity and site-default palette come through Discourse DTOs; unknown/custom icon or emoji identifiers use a color square. Deployed member-specific scheme selection, secure media and complete lazy catalog remain open. Background identity fields are decoded but not drawn behind text. See [API status](../discourse-api-reference.md), [native architecture](../architecture.md) and [validation](../implementation-status.md).

The latest approved screenshot remains the design reference. Historical statements above that no app code changed refer to those earlier design-only turns.
