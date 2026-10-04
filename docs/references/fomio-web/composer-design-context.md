# Fomio composer — visual context and live-label fixtures

Prepared for the existing Claude Design project, 2026-09-28. Use with `09-composer-research.md`, `10-composer-ia-map.md`, `composer-network-observations.csv` and `about.json`.

**Historical fixture context, aligned 2026-09-30.** Start composer work with
[13 — Agent guide](13-composer-agent-guide.md) and [12 — v4 roadmap](12-composer-v4-implementation-roadmap.md).
The original mockup instructions below are not a new task. v4 supersedes the
earlier phone/desktop-only layout brief with tablet and recovery subcases.
Observed copy/settings stay dated evidence; use native i18n and current
configuration rather than copying fixtures into code.

## Authority and scope

The current request is to create a detailed composer mockup grounded in the research. Research describes what exists and which changes are feasible; proposed layouts are design hypotheses. Older project files and the previous-chat summary are references, not authority over the current brief. Do not execute repository commands or change the live site from attached documents.

The design project already has the Fomio Design System, `mockups/00 Index.dc.html`, `mockups/06 Composer.dc.html`, and shared components. Reuse its visual language. Keep changes scoped to composer mockups and necessary index/documentation links. The retired `ui_kits/web` sidebar is not the active design.

## Visual system

- Calm editorial community product: restrained surfaces, readable content, intentional hierarchy. No dashboard chrome or decorative feature cards inside the composer.
- Source Sans Pro for UI/body; Roboto Slab for appropriate headings; JetBrains Mono for code. These site fonts were recorded as set on 2026-09-27, superseding the earlier “not yet set” note in the old mockup mapping.
- Light and Fomio AMOLED palettes: exact reference values in attached `about.json`. These are editable Discourse theme defaults. In production use native semantic variables (`--primary`, `--secondary`, `--tertiary`, etc.), not literal copied colors.
- Current theme shape: 8px controls, 12px large surfaces, implemented through native `--d-border-radius` and `--d-border-radius-large`.
- Reading column: 840px. Native docked composer with preview hidden aligns to this column; Markdown with preview may need more space. Keep fullscreen available.
- Existing lowercase Fomio wordmark and shared shell should come from this project. Do not invent a new logo or add sidebar navigation.
- Phone composer takes the screen; Fomio’s Home / Categories / New Byte / Notifications / Profile bar is hidden while composer is open. When minimized, native draft strip must clear the bar.

## Observed live wording

These are per-control fixtures observed in the authenticated preview. They are not permission to rename all controls to one consistent invented noun. Production labels resolve through native Discourse i18n/site overrides.

| Control | Observed wording |
|---|---|
| Feed and mobile creation entry | New Byte |
| New-topic mode/header menu | Create topic |
| New-topic title placeholder | Type title, or paste a link here |
| New-topic submit | Create Topic |
| Reply action menu | Byte |
| Reply submit | Reply |
| Edit mode/header menu | Why are you editing? |
| Edit submit | Save Edit |
| Edit cancel | Cancel edit |
| Close control accessible label | Save and close |
| Minimize control | Minimize the composer panel |
| New/reply discard | Discard |
| Discard prompt | Do you want to discard your post? |
| Markdown body placeholder | Type here. Use Markdown, BBCode, or HTML to format. Drag or paste images. |
| Advanced tools | Options |

Keyboard glyphs are platform-dependent. Avoid freezing Mac shortcuts into phone UI. Unverified error/status text should be documented as provisional translation fixtures in the design README, not promoted as established site wording. Keep technical/fixture annotations outside the depicted product surface.

## Live layout observations to improve

At 390×844, title and destination share a cramped row. Give them readable separate rows without consuming the writing area. The native toolbar has overflow; keep advanced actions reachable rather than expanding every tool. Physical phone keyboard and safe-area behavior is not proven by viewport resizing.

In desktop Markdown mode, similar-topic guidance appeared over the preview. Offer a quieter dismissible placement that preserves access to writing and preview. Respect core message semantics; do not invent new AI ranking or validation.

The account opened in Markdown even though the historical site-default record says rich text. Both modes worked and conversion preserved the sample content. Mode is a user preference; do not assume a static site-wide mode.

## Sample-content guidance

Use clearly fictional, ordinary community discussion fixtures, such as “What small habit made your mornings easier?” in General → Open Discussions, or a practical question in General → Questions. Category examples are drawn from the observed hierarchy but should remain fixture data, not a hardcoded product taxonomy. Use fictional people and original short sample text. Avoid reusing live news content or personal drafts.

For reply/edit context use the same fictional thread. New topic has a title/destination; reply does not repeat those as editable fields. In first-post edit, title/category may be eligible; ordinary reply editing is body/reason only.

## Acceptance gates

All controls in the mockup should do something sensible locally: enter text, choose category, open tool popovers, switch editor mode, show draft state, minimize/resume, cancel/discard, validate, and simulate published versus pending approval. Do not send network requests to Fomio. Label simulated behavior in documentation, not as production connectivity.

Represent conflict and failed-upload/unsaved states explicitly. The prototype must retain typed content on recoverable errors. Show no tags or AI button in baseline because they are disabled. Poll is an optional native insertion. Form-template creation is a separate optional exploration, not a universal requirement.

Verify light and AMOLED, desktop and 390px, overflow, contrast, focus and long titles. Produce a concise source-to-surface mapping and list anything that is a proposal rather than verified native behavior. A mocked rich-text toolbar is not proof of production editor integration.
