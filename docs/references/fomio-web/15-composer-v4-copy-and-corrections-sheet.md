# 15 — Composer v4: copy decisions and design corrections (stage 0)

Prepared 2026-09-30 for review. The evidence is in `composer-v4-stage-0/composer-v4-copy-mapping.csv`
(101 rows), checked against locale files at Discourse `7b4f0970`. The captured
states are in `composer-v4-stage-0/screenshots/`.

**Default rule:** a label shows whatever Discourse's own i18n key renders.
The mockup text is a fixture. The site's existing text overrides ("New Byte",
"Create topic", "Byte") stay as they are. Nothing in this sheet is an approved
override or new key. D1–D10 and LT (large-text status) are still pending.

## A. Mechanical design corrections (no product choice)

Fixes that make the reference match native behaviour or its own inventory.
Recommended for the designer before the snapshot is approved. Any change means
a new snapshot.

| # | Correction | Evidence |
|---|---|---|
| A1 | Replace these mockup strings, which were labelled "core" but don't match core, with the actual core wording (right-hand column) | copy-mapping rows marked "core fixture (claimed)" |
| | Saving draft… | Saving |
| | Draft saved | Draft saved! |
| | Edit conflict | edit conflict |
| | Overwrite Edits | Overwrite Edit |
| | Unable to connect. | Network Error / Please check your connection. |
| | Insert Hyperlink | Insert link |
| | Link text (optional) | Link text |
| | Build Poll | Build poll |
| | Insert date | Insert date / time |
| | Single/Multiple choice | Single Choice / Multiple Choice |
| | This field is required | Please fill out this field. |
| | Search categories | Search… |
| | Approval dialog body | review.approval.description |
| A2 | Poll validation copy in C08-8 asserts a **2-option minimum**. Core enforces **1** (poll.ui_builder.help.options_min_count, server default_poll_must_have_at_least_1_option), and its uniqueness error is "Poll must have different options." Fix the rule as well as the copy. | poll plugin locales; S18 |
| A3 | Remove "Keep editing" and "Save draft for later" as claimed core strings. The native discard dialog offers Discard and Cancel (`cancel_value`). Wherever v4 keeps "Keep editing", treat it as a new label (C). | services/composer.js#cancelComposer, modal/discard-draft.gjs |
| A4 | TAB-9 has two meanings (I-1). Give the uploads-during-rotation state its own ID. | S06, S07 |
| A5 | Define or renumber C12-6 (I-2). Decide whether C13-1 and C14-1 are real subcases or aliases (I-3). | LIB |
| A6 | Frame the `noReply` banner ("You can no longer reply here.") or delete it (I-9). | FMC4 BN.noReply |
| A7 | M3 and C07-6 at 390×844: the tray covers the text whose selection it claims to keep. Scroll the selection into view in the reference frames (I-12). | S03, S09 |
| A8 | Dialog roles: use `dialog` for ordinary form sheets and keep `alertdialog` for destructive or urgent confirmations, per doc 12 (I-4). | FMC4; HO§7 |
| A9 | Add FmHeader and FmBottomNav to the reference baseline. FmComposer4 imports them, and without them page views render blank (I-11). They're fetched in the addendum. | capture attempt 1 vs 2 |
| A10 | Use correct image file extensions in the design project; `v4-a.png` is JPEG (I-10). | `file` output |

## B. Use native core wording (recommended default, 64 rows)

- **CORE-EXACT (31 rows):** render as-is. Examples: Edit link, Remove link,
  Link, Paragraph, Heading, Timezone, Date, Time, Options (one per line),
  Summary, Uploading…, Your topic is similar to…, Reply as linked topic,
  Continuing the discussion from, Drafts, Resume, You were logged out., Try
  Again, Sorry, an error has occurred., Log In, Sign Up, Quote, Insert table,
  Hide details, Blur spoiler, Preformatted text, the validation messages
  (title/post length, Title is required), No matches found, Post Needs Approval.
- **CORE-DIFFERENT (33 rows), recommended to adopt the core wording:**

| Mockup label | Core wording |
|---|---|
| Bullets | Bulleted list |
| Numbers | Numbered list |
| Quote (tray) | Blockquote |
| Subheading | Heading %{n} |
| Alt text / Describe the photo | Add image description |
| Remove (image) | Remove image |
| Upload failed… | post.errors.upload |
| Draft-conflict text and actions | core Reload / Ignore; tied to D3, so stays pending |
| Offline / not-saved status | drafts offline; tied to LT, so stays pending |
| Preview-failed note | Could not load preview; tied to D7, so stays pending |

  The rows tied to D3, LT and D7 follow the default only once those decisions
  are made.

## C. Intentional wording changes (user choice; core key exists)

Each of these would change what an existing core concept is called. Pick one
option per row: (a) keep core wording, (b) a site-text override (this is
global), or (c) a scoped theme key with a stated reason.

| Label | Core renders | Note |
|---|---|---|
| Photo | Upload | Strip label |
| More | Options | **D2** |
| Bold / Italic (visible) | Strong / Emphasis | "Bold" and "Italic" exist only in the keyboard-shortcut help |
| Public / "[Groups] only" | Public / Private | Naming groups has no core phrase |
| Add edit reason | none in the composer (only the table builder's "Add reason for edit") | Field placeholder stays "Why are you editing?" (observed) |
| Copy text / Text copied | Copy link / Link copied! (link toolbar only) | Tied to D3/D4 |
| Drop images to upload | Click to upload or drag & drop file (upload selector) | Different surface |

## D. New labels (no core key; decide per group)

Each group is either kept, with a new theme key and a stated reason (doc 13
rule 6), or designed out. Where a group depends on a pending decision, its
labels follow that decision.

| Group | Labels | Depends on |
|---|---|---|
| Strip | Format, Hide keyboard | — |
| Draft recovery | Draft not saved (status), You're offline. Draft not saved., Retry save, Draft not saved. bodies, close-blocked text | D4, LT |
| Draft conflict | This draft changed somewhere else., Save mine over it, Use the other version, Replace… | D3 |
| Submission outcomes | Not posted. / Not posted yet., Choose another category, You can no longer post in [category]., This topic was closed while you were writing., Edit saved | — (native reasons remain the body text) |
| Uploads | Wait for the photos to finish uploading., Finish or remove uploads first, Add (n) | — (Add (n) may be moot with the OS picker) |
| Insert sheets | Text to blur, Code, Language, Add row/column, Add a summary., Choose a date., Add the text to blur., Add the code or text to preformat., Add at least one column heading. | D6 |
| Link preview | Preview unavailable. The link will be posted as written. | D7 |
| Guided form | Switch to [category]?, Switch and keep answers/text | D5, D8 |
| Other | Suggestions (mention list), Writing in rich text/Markdown sub-lines | — |

## E. Product choices (pending; not decided here)

D1 (tablet sizing), D2 (More vs Options), D3 (draft conflict actions), D4
(offline close), D5 (form switch), D6 (insert sheets), D7 (preview note), D8
(ship guided form), D9 (emoji), D10 (session resubmit), LT (large-text
status). Plus the C rows above and the keep-or-drop call for each D group.

New visual evidence for reviewers (renders of the frozen design prototype, not native Discourse or device proof):

- **S16:** the drawn More sheet has **no emoji tool** (D9).
- **S41:** at 150% zoom the unsaved status is **only a warning icon**; the
  banner below still states it (LT).
