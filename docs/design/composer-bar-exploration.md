# Composer bar exploration — 2026-10-05

Status: design proposal requested by the user; not an accepted replacement for the native composer. Scope is bar interactions and reviewable mockups. Existing application edits and prior design snapshots remain separate.

## Evidence and provenance

The user requested Gutenberg-mobile-like UX inspired by `/Volumes/Develop/Projects/Fomio/apps/mobile`, and authorized Claude Design mockups. Reference documents describe previous choices; they do not independently authorize new features or deployment.

Expo repository HEAD inspected: `3651cd47472256938f504049e5a9f239fb973539`. Working files were read; the revision alone does not assert a clean checkout.

- `src/components/compose/BlockContextualBar.tsx`: write, selection-format, and inline type/insert picker modes; editor-reported active formatting; heading/code context; history and keyboard dismissal. Pickers cross-fade at a fixed height. Aa transforms; + inserts.
- `src/components/compose/ComposeEditorAccessory.tsx`: floating pill with 16pt keyboard gap and safe-area handling, plus a docked alternative.
- **Current create and edit screens** (`app/compose.tsx`, `app/feed/[byteId]/edit.tsx`) use the **docked** `ComposerActionBar`, with undo/redo, optional photo, formatting sheet, preview and word count. The architecture document's floating-pill description and some code comments lag these call sites. The retained contextual component is interaction inspiration, not the current screen wiring.
- `docs/20-implementation/composer-architecture.md`: raw Markdown authority, editor-owned history and caret state, warnings for unsupported serialization. TenTap/TipTap is the implementation; these reads do not establish use of the Gutenberg engine.
- Native `Fomio/Features/ComposerView.swift`: keyboard-only accessory with Bold/Italic/Link/photo when they fit, otherwise More; insertion forms, rich/source switch and undo/redo in More. Focus/selection suspension exists for secondary presentations. The proposed block transform and contextual controls need native implementation work.

Claude Design project: [Fomio iOS IA & Wireframes](https://claude.ai/design/p/4e5074c6-0b81-4e0d-a216-04b839117fec). Requested new file: `Fomio Composer Bar Lab.dc.html`. Prior files are references; this exploration should not overwrite them.

## Proposed direction

Compare A, a contextual floating bar, with B, a compact docked keyboard bar, using the same document. A is the initial recommendation for review because it exposes the current block and separates insertion from transformation. B offers a stable keyboard edge and more room.

Compact writing core: **+ · current block/type · Bold · Italic · More · hide keyboard**. Keep at least 44pt targets. Do not compress eight buttons onto a narrow phone. History, link, preview and source mode remain discoverable through labeled More. Selection changes central tools while keeping persistent controls predictable. Code and selected photos get relevant actions rather than inappropriate inline formatting.

Aa/current type transforms the active block. + inserts a new block. Compare the lightweight Expo chip strip with a searchable sheet grouped into Text, Media and capability-gated Advanced tools. No desktop settings sidebar or hover-only action.

## Interaction contract for mockups and later implementation

| Event | Document and selection | Focus and presentation |
| --- | --- | --- |
| Enter composer | Preserve resumed raw text, photos and context | Keyboard initially down; body tap begins writing |
| Select text | Read editor's actual range and active marks | Contextual formatting; native selection UI remains available |
| Bold/Italic | Apply to selected range or typing attributes | Keep selection/focus and keyboard steady |
| Change type | Transform current compatible block, retaining text | Quick picker may stay above keyboard; return to writing after apply |
| Open inserter/link form | Capture range, active block and prior focus | One presentation; dismiss body keyboard before sheet |
| Cancel secondary presentation | No mutation; restore captured range | Restore prior focus only if it was previously active |
| Apply insertion/link | Use captured position, not document end; advance caret appropriately | Close presentation and resume prior writing context |
| Hide keyboard | No document mutation; retain range | Keyboard down; composer remains open, tools still reachable |
| Preview → writing | Preserve raw text and selection | Hide keyboard in preview; restore writing context on return |
| Undo/Redo | Use native editor history; show actual enabled state | Do not invent a separate snapshot history |
| Select photo / failed upload | Preserve photo and text; Retry/Remove are explicit | Photo-specific controls; unresolved upload prevents Post |
| Locked submission | Preserve writing and distinct outcome state | Editing disabled; recovery actions remain reachable |

## Adaptation and limits

Review light/AMOLED, 375×667, large text, Arabic mirrored RTL, Reduce Transparency/Motion and iPad hardware keyboard. Keep the final line scrollable above controls. Narrow/large-text variants may move secondary controls into labeled More. Body Return inserts a newline; new-topic title Next moves to body. Hardware-keyboard users still need access to editing tools.

Local drafts retain selected photo bytes as established by the native implementation; older mockup warnings about losing unfinished photos are superseded. Advanced insertions depend on actual Discourse capabilities. No backend contract, deployment resource or plugin availability is established by this design task. Browser keyboard/material/selection simulations are not native acceptance.

Official references: [WordPress block UI](https://developer.wordpress.org/block-editor/explanations/user-interface/), [adding blocks](https://wordpress.org/documentation/article/adding-a-new-block/), [Apple virtual keyboards](https://developer.apple.com/design/human-interface-guidelines/virtual-keyboards), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars), [sheets](https://developer.apple.com/design/human-interface-guidelines/sheets). Apple keyboard, toolbar and sheet guidance was read live in the browser: relevant accessory controls, system positioning/padding, Liquid Glass consistency, deliberate grouping and explicit cancellation inform this proposal. WordPress contextual block and searchable inserter guidance supplies interaction inspiration, not native API behavior. For a native iPad standard toolbar, prefer the system's automatic overflow handling; the custom browser More treatment is illustrative.

## Review evidence

Created [Fomio Composer Bar Lab](https://claude.ai/design/p/4e5074c6-0b81-4e0d-a216-04b839117fec?file=Fomio+Composer+Bar+Lab.dc.html) with A/B comparison, clickable A prototype, 17 presets, interaction specification and state matrix. Claude reported no prior project-file edits; the page list shows prior composer/screen-pack files still dated the previous day. The new design remains a proposal.

Independent Codex browser checks:

- Selection preset → Bold: active state changed, the phrase range and keyboard-up state stayed. Repeated after the final bar-width correction.
- Selection Done → current type → Heading 2: transformed block 1 in place, retained focus and keyboard-up state.
- + → Cancel: inserter named the captured block; cancellation returned to the same heading/caret with keyboard up.
- Hide keyboard: retained heading/caret, kept bar and composer accessible with Show keyboard.
- More → Preview → Edit: preview opened with keyboard down; Edit returned to composing. Detailed return-range checks remain native acceptance work.
- Failed-photo preset: Retry/Remove visible, Post disabled. Retry showed progress, then completed and enabled Post.
- Narrow 375×667: final revision visibly fits +, Paragraph, Bold, Italic, More and keyboard controls; More opened successfully with actual disabled Undo/Redo states. This is visual/interaction evidence, not measured native target geometry.
- Arabic preset: visually mirrored header and writing layout; translation quality was not evaluated.

Claude's own check report additionally covers inserting Photo after the focused block, dark, large text, iPad, chip inserter and link/search presets. Those are generator-reported checks, not all independently repeated by Codex. Claude's automated review found bar overflow on narrow and default phones and refined the type chip to remove its glyph on iPhone. Codex refreshed the preview and checked narrow More reachability after that change.

[Local screenshots](snapshots/2026-10-05-bar-lab/README.md) preserve narrow writing and final selected Bold states. The file's Download action did not return a download or a local authored source; no offline source export is claimed.

### Refinements before implementation

- The block prototype inserts **after the captured block**. Native inline photos/links already work with raw selection ranges. Decide the placement policy explicitly: full block insertions may go after a block; inline actions must honor the saved range. Do not silently replace the native caret behavior.
- The prototype's immediate Close → saved-draft/reopen simulation is narrower than the native Keep editing / Keep draft / Discard guard. Keep the native explicit exit choices; a bar exploration does not approve changing draft lifecycle.
- The A comparison copy claims one-tap Link while writing, but the paragraph bar has Bold/Italic and Link is exposed on selection or a heading. Reconcile that copy and provide a discoverable link action at a collapsed paragraph caret before implementation.
- Default preview content initially scrolls near the last paragraph; title/community are static context in the prototype. It is a bar model, not a complete composer replacement.
- Rich/source parity, exact selection, title Next, body newlines, IME, actual keyboard anchoring, photo picker return, VoiceOver, safe areas and hardware-keyboard shortcuts still require native validation. Browser history and drafts are simulated. Some empty-message logs were reported by Claude without a traced cause; no blanket zero-error claim is made.

## Native implementation of A — 2026-10-05 (working tree)

Status: implemented natively behind no flag; replaces the keyboard-only accessory. Design source read from the Claude Design project file `Fomio Composer Bar Lab.dc.html` (sections 1–5). This is not device acceptance.

What is built (`Fomio/Features/Editor/ComposerBar.swift`, `ComposerView.swift`, `NativeComposerEditor.swift`, `ComposerDocument.swift`):

- **Floating pill**: Liquid Glass capsule, 12 pt side insets, 8 pt above the keyboard or the safe area; solid fill with border under Reduce Transparency; mode swaps are instant under Reduce Motion. On iPad (regular width) the pill is centred at ≤ 620 pt and adds Link, Undo and Redo.
- **Modes**: entry (+ · More · Show keyboard) before the body has had focus; title (+ disabled, “Title · plain text”); write by block type: paragraph/quote/list → type chip · Bold · Italic (· Link when it fits), heading → type chip; selection → Bold · Italic · Link · Quote · Done (heading: Quote · Done); Turn into strip; caret beside a structured block → + · More only. At accessibility text sizes, the bar uses + · More · Done/Keyboard; formatting and transformations remain in More. Icon glyphs and hit targets stay bounded (20 pt glyphs, 44 pt targets); text labels use semantic fonts.
- **Turn into**: Paragraph, Heading 2, Heading 3, Quote, Bulleted list. A new `EditorCommand.style` rewrites only the Markdown line prefix of the touched lines, keeps the caret relative to the text, is one undo step (“Change block type”), and refuses lines inside structured blocks (code, table, poll, photo…). Keyboard and focus stay up.
- **Headings are now editable text** in rich mode. Previously `# …` lines were opaque cards. The `##` marker stays visible in tertiary colour so display and raw offsets are identical; heading weight is not reported as Bold. Ordered lists, task lists, rules and `~~~` fences stay opaque.
- **+ → Add block sheet**: search; Text / Media / Advanced; Advanced lists only blocks in `composerCapabilities`. The sheet states the placement, quoting the captured block (“Adds after “…””). Cancel or swipe mutates nothing and restores the captured focus and caret.
- **Placement policy (resolves the refinement above)**: + inserts *after the captured line* (or reuses an empty line; after a structured block when the caret is beside one). More → Add photo keeps the established *inline at the saved range* behaviour. Link always honours the saved range.
- **Hide keyboard** only resigns focus; the bar stays docked with Show keyboard, which returns to the remembered caret (or an empty new-topic title).
- **More** (icon-only on the full and accessibility rows, labelled in the width fallback) holds Format, Turn into, Add block…, Add photo, Markdown, Undo/Redo with real enabled states. Bold, Italic and Link are disabled for selections touching headings or structured blocks, with editor-command guards as well. The native Keep editing / Keep draft / Discard exit guard is unchanged.

Deviations from the mockup, deliberately: no Preview (the native composer has none yet); no word count in More (needs a pluralised Arabic string); the chip-strip inserter option was not built (comparison only); no Bold/Italic/Link inside headings, because inline markup inside a heading line renders literally in this editor; on 375–402 pt iPhones the paragraph row usually drops Link for width, which stays one tap deeper in More → Format and in selection mode. Existing heading inline markup remains source-preserved; converting formatted text to a heading can still expose its literal markup.

Arabic strings were added for every new label; they have not been reviewed by a native speaker.

Verified in the iPhone 17 Pro simulator (iOS 26.1, hardware keyboard connected): entry bar with keyboard hidden; paragraph write mode; Turn into → Heading 2 transformed in place with the caret kept; + sheet named the captured block; Cancel restored the caret; + → Quote inserted a new line after the block with the caret inside it, and typing went into the quote; double-tap selection showed Bold · Italic · Link · Quote · Done; Bold applied and kept the selection. Unit tests cover restyle, caret mapping, structured-block refusal, insertion placement, heading parsing and the style command's undo. UI test `testFloatingBarTurnsBlockIntoHeadingAndInserterCancelKeepsCaret` covers the software-keyboard path.

Still needs native validation: software-keyboard geometry on 375×667 and at accessibility sizes, VoiceOver order and announcements, RTL mirroring of the pill, iPad hardware-keyboard shortcuts, photo-picker return after + → Photo, IME input inside headings and quotes, and Reduce Transparency appearance.

## Composer design audit and refinement — 2026-10-07

The current native composer was audited at `a93cb62` and refined in the working tree using the Build iOS Apps UI patterns, input-toolbar, grid, sheets and Liquid Glass guidance. The user's requested references are interaction sources; the application remains a native Discourse client.

### Reference patterns

| Reference | Observed pattern | Application to Fomio |
| --- | --- | --- |
| [Notion mobile editing](https://www.notion.com/help/writing-and-editing-basics) | Mobile insertion lives above the keyboard; block insertion and transformation have separate purposes. | Keep + stable, retain the block-type control, and make insertion scannable. No hover handles or desktop slash-command requirement. |
| [Gutenberg toolbar](https://developer.wordpress.org/block-editor/reference-guides/components/toolbar/) and [mobile source](https://github.com/wordpress-mobile/gutenberg-mobile/blob/trunk/bundle/android/strings.xml) | Related options share a consistent toolbar; mobile guidance locates insertion at bottom left and formatting above the keyboard. | Separate Add, edit tools, and Done/keyboard into predictable visual groups. |
| [Tiptap BubbleMenu](https://tiptap.dev/docs/editor/extensions/functionality/bubble-menu) | Formatting responds to text selection. | Keep the contextual selection row. Native selection handles and the system Cut/Copy menu retain their normal behavior; a second bubble near the selection would compete with them. |
| [Arc command access](https://resources.arc.net/hc/en-us/articles/20855018192791-Site-Search-Directly-Search-any-Website) and [iOS refinements](https://resources.arc.net/hc/en-us/articles/23528454620311-Arc-Search-for-iOS-Release-Notes) | Focused search reduces navigation steps; published refinements include text scaling, RTL and selection-handle fixes. | Search blocks by their purpose as well as name. Restraint, stable focus and adaptable controls are design interpretations, not claims of product parity. |
| [Telegram attachment menu](https://telegram.org/blog/downloads-attachments-streaming) and [drafts](https://telegram.org/blog/drafts) | A dedicated attachment surface and recoverable unfinished writing support quick composition. | Put Photo in the first row of the insertion sheet and preserve the existing protected local draft behavior. This does not introduce cloud draft sync or Telegram's media capabilities. |
| [Apple toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars) and [materials](https://developer.apple.com/design/human-interface-guidelines/materials) | Deliberate item choice, logical groups and a restrained glass control layer preserve hierarchy. | Use separators and a neutral type chip in the floating toolbar; use ordinary themed fills for catalogue content. |

### Audit findings and delivered changes

- The purple outlined type chip competed with the filled Add control. It now uses a quieter fill, the short visible label Text for a paragraph, and a consistent transform chevron. Its accessibility label still states the complete current block type.
- Add, formatting, and finishing actions appeared as one undifferentiated row. Separators now establish groups, including a distinct Done/keyboard action. The accessibility-size three-control row remains available. Add uses the theme's contrast-aware on-accent ink.
- The Add block sheet was a long generic list. Photo and Quote now lead as quick cards; text and capability-gated advanced choices use readable rows with purpose descriptions. Search matches descriptions (for example, vote finds Poll). Quick cards collapse to a single column at accessibility sizes. Native search cancellation precedes sheet dismissal when search is active.
- More → Emoji merely refocused the editor. The inert action was removed; the system keyboard remains the place to choose emoji.
- Focus/selection, line placement, source mode, undo, draft protection and backend permission ownership remain part of the existing editor contract. The new catalogue uses the same captured insertion operation.

### Remaining design constraints

Full inline formatting inside headings remains unavailable; existing heading markup can display literally. Ordered/task lists and unsupported blocks remain bounded native projections. A fully polished block-writing experience would need richer projections and explicit block operations with source-safe selection mapping. Dragging/reordering blocks, slash commands, collaboration and AI are outside this refinement. Native image selection/cancellation, physical VoiceOver, narrow phones, iPad window resizing and floating keyboards still need their own acceptance evidence.

### Validation and native captures

Built successfully and verified eight distinct fixture UI journeys on an isolated iPhone 17 Pro simulator, iOS 26.1: contextual selection formatting, purpose search and quick quote insertion, Arabic mixed-text editing and rotation, dark accessibility text, largest-text selection reachability, heading transformation and insertion cancellation, keyboard Next/Keep editing, and structured-block Markdown round trip.

The eight-test run passed seven journeys; the new catalogue test initially failed because it expected a Cancel label for iOS 26's icon-only Close search control. After correcting the test query, the catalogue journey passed independently, including search cancellation without a draft mutation or keyboard reopening and quote insertion with exact raw Markdown. No production changes were required for that test correction. Result bundles: `/private/tmp/fomio-polish-verified-20261007.xcresult` (7 passed, 1 failed) and `/private/tmp/fomio-polish-catalogue-final.xcresult` (1 passed, 0 failed). Earlier shared-simulator runs were interrupted and are not acceptance evidence.

Native screenshots were exported and visually inspected: [writing bar](../validation/2026-10-07-composer-polish/writing.png), [insertion catalogue](../validation/2026-10-07-composer-polish/inserter.png), [contextual selection](../validation/2026-10-07-composer-polish/selection.png), [largest-text controls](../validation/2026-10-07-composer-polish/accessibility.png), and [Arabic rotation](../validation/2026-10-07-composer-polish/arabic.png). These captures document the native implementation; exhaustive accessibility and product parity remain unclaimed.
