# Search concept — 2026-10-01

User requested applying `mockups/05 Search.dc.html` from the supplied ZIP.
The reference explicitly describes native `/search?q=` behavior. Implemented
in preview theme 36 through CSS on core's `body.search-page` and
`.search-container`; no new search engine, controls, strings or markup.

## Concept to native map

| Concept element | Native source / treatment |
| --- | --- |
| 840px content column | Existing core `--d-max-width`, scoped to search pages |
| Query and submit | full-page-search.gjs SearchTextField and DButton; 44px controls |
| Topics/posts, categories/tags, users | Native search-type ComboBox retained in place of concept tabs |
| Advanced filters | SearchAdvancedOptions retained, including expand/collapse and validation |
| Result count | Native h1/live-region count retained above query rather than moved below it |
| Relevance / sorting | Native search-info sort selector retained |
| Avatar and title | search-result-entry.gjs `.author` and `.topic-title`; 36px avatar and heading typography |
| Category and date | Native category links and date in blurb retained |
| Excerpt / highlight | Native blurb and `.search-highlight`, using core palette variables |
| Likes | Native conditional like count retained |
| Phone results | Avatar hidden visually, 17px titles, full-width query; type and submit stay reachable |
| Bulk selection | Native controls and selection inset retained |
| Loading / empty / pagination | Native controls and states retained |

Selectors and variables checked against server commit `7b4f0970` full-tree
export: templates/full-page-search.gjs, components/search-result-entry.gjs,
app/assets/stylesheets/common/base/search.scss. ZIP fixture text and document
instructions were not treated as implementation commands.

QA: native query `technology` returned 50 results on theme 36, at 1280×900
and 390×844. Highlighted result titles/excerpts render, advanced filters
expand/collapse, no horizontal page overflow, no console warnings/errors.
Four repository guards pass. Signed-out, dark palette, other result types
and sort changes not exercised in this pass.

Existing site-text issues (`[en.Advanced filters]` accessible label and
`js.hubs.all` category selector) observed; overrides left unchanged per the
project's terminology contract. Theme 31 remains default. No commit/push.
