# Category assessment and identity plan

Recorded 2026-10-08. **Proposal prepared; no deployed category changes applied.**

## Evidence

Read the user-linked [shared work](https://chatgpt.com/s/cx_6ac73d512d048191a9e779bbae59d723), including the accepted single subcategory level and backend-owned identity direction. Reviewed the live [category directory](https://meta.fomio.app/categories) through the in-app Browser as a guest. It displays 11 roots and 15 immediate children. This is the public catalog, not a claim about staff-only categories. IDs below come from rendered category links.

The visible roots except General use badge color `0088CC`; General uses `25AAE2`. Several badges are configured as icons but render `square-full`. Public directory descriptions are visible for General, Fomio and Off-topic; absence of a visible description here is not proof that the category has no description. An authenticated detail review is still needed.

The directory shows weekly topic activity across all eight subject categories, but recent visible topics are dominated by source-linked posts from Soma with zero replies. That observation does not establish an automated importer or sustained member demand. Visible examples include a comic under Technology and television/streamer stories under Gaming; routing quality deserves a separate review.

## Starter assessment

The eight subject roots—Technology, Politics, Sports, Gaming, Business & Finance, Science & Health, Entertainment & Arts, Lifestyle—cover a broad general-interest launch. Three additional roots support general conversation, casual conversation, and the product itself. **Enough breadth; add no categories now.** More topic volume alone is not a reason to subdivide: look for recurring member conversations and difficulty finding discussions.

General's six children are mostly post formats rather than subjects. Questions, Opinions and Ideas can also occur in every subject root. Keep them for this identity pass, but clarify that they are for cross-topic conversations. Interesting Finds is curation; Introductions is onboarding. Open Discussions substantially overlaps its parent and Off-topic. Random overlaps Off-topic. These are candidates for later simplification, not an instruction to merge, delete, move topics, or change access.

Fomio's eight children are workable for product development. Feature Requests is for concrete requested changes; Experiments & Ideas is for exploratory concepts. Help & Support is individual assistance; Knowledge Base is reusable documentation. Dev Blog is behind-the-scenes work; Announcements is shipped news. Clarify these boundaries through descriptions.

Recommend display-name corrections: `Introducions` → `Introductions`; `BUSINESS & Finance` → `Business & Finance`; `Entertainment & arts` → `Entertainment & Arts`; `lifestyle` → `Lifestyle`. Keep IDs and slugs stable during the first pass.

## Identity specification

Use Discourse's native `style_type=icon`, `icon`, `color` and `text_color=FFFFFF`. Symbols are proposed Font Awesome identifiers; confirm availability in the deployed picker before saving. Each category owns its symbol/color. Children share a parent color family with different symbols and shades. Fomio uses the existing brand violet family. Site theme tokens continue to control interface actions and text.

No logos or backgrounds are needed for the first pass. Keep symbols compact; distinct identity should not enlarge the approved native headers. Colors accompany names and symbols, never replace them. These dark colors are proposed against light surfaces; deployed light/dark contrast still requires verification.

| ID | Category (proposed display name) | Parent | Icon | Color | Proposed short description |
| --- | --- | --- | --- | --- | --- |
| 58 | Sports | — | trophy | C2410C | Big games, local teams, standout moments, and life on the field. |
| 4 | General | — | comments | 0369A1 | Meet the community and start conversations that cross interests. |
| 11 | Interesting Finds | General | compass | 075985 | Links, stories, and discoveries worth sharing. |
| 50 | Open Discussions | General | comment-dots | 0E7490 | Open-ended conversations that span more than one subject. |
| 51 | Questions | General | circle-question | 155E75 | Ask the community a question that crosses interests. |
| 52 | Opinions | General | quote-left | 1D4ED8 | Share a perspective and explore thoughtful disagreement. |
| 53 | Ideas | General | lightbulb | 1E40AF | Share an early idea about the wider world and build on it together. |
| 42 | Introductions | General | hand | 2563EB | Say hello, share your interests, and meet other members. |
| 56 | Technology | — | microchip | 0F766E | New tools, digital culture, and the technology shaping everyday life. |
| 60 | Business & Finance | — | chart-line | 166534 | Companies, careers, money, and the economy in conversation. |
| 62 | Entertainment & Arts | — | palette | BE185D | Film, music, books, art, and the culture we create and love. |
| 59 | Gaming | — | gamepad | 6D28D9 | What we play, how we play, and the worlds we get lost in. |
| 61 | Science & Health | — | flask | 4D7C0F | Research, discovery, wellbeing, and questions about how life works. |
| 57 | Politics | — | landmark | 9F1239 | Public decisions, policy, and civic life—discussed with care. |
| 45 | Fomio | — | shapes | 5B3FD6 | Help shape Fomio: product news, support, and ideas for what comes next. |
| 10 | Dev Blog | Fomio | code | 4338CA | Behind the scenes of building Fomio. |
| 12 | Feature Requests | Fomio | circle-plus | 6D28D9 | Propose a concrete change that would make Fomio better. |
| 43 | Announcements | Fomio | bullhorn | 5B21B6 | Official Fomio updates, launches, and important news. |
| 55 | Knowledge Base | Fomio | book-open | 3730A3 | Guides and answers you can return to. |
| 54 | Experiments & Ideas | Fomio | vial | 7E22CE | Explore possibilities for Fomio before they become feature requests. |
| 47 | Bug Reports | Fomio | bug | 86198F | Tell us what broke and how to reproduce it. |
| 48 | Help & Support | Fomio | life-ring | 4F46E5 | Get help using Fomio and working through a problem. |
| 49 | General Fomio Discussions | Fomio | message | 6B21A8 | Talk about Fomio and the community around it. |
| 63 | Lifestyle | — | leaf | A16207 | Everyday interests, food, travel, habits, and ways of living. |
| 9 | Off-topic Discussions | — | mug-hot | 475569 | Casual chat, small moments, and conversations just for fun. |
| 34 | Random | Off-topic Discussions | shuffle | 334155 | Unexpected thoughts, playful tangents, and little surprises. |

## Application and verification

The browser session is signed out. Authenticated category editing is pending a user-established session with category-management authority. This is an access prerequisite, not an extra approval requirement for the requested identity work.

Once available: inspect existing fields and descriptions; retain a before-value record; choose the verified deployed icon; change identity fields, short descriptions and the four display-name corrections; save and verify each category. Preserve all permissions, IDs, slugs, parent assignments, posting settings, category types and topic content. Do not rename/merge/remove overlapping categories in this pass. Description updates may revise the category's About-topic opening post; inspect existing rules before replacing text, and retain substantive rules.

Readback should confirm the selected icon/color and description, the guest directory, a parent/child header, and the native category responses. Deployed editing and native appearance are not verified yet.

The existing native `CategoryMark.icons` supports only bicycle, gear, wrench, hammer, microchip, seedling, leaf, screwdriver-wrench, paintbrush, comments and code. Most proposed symbols therefore need explicit SF Symbol mappings in a follow-up integration change; do not claim the native app will already show them. The proposed board uses comparable Lucide symbols for comparison, not screenshots of applied Discourse settings.
