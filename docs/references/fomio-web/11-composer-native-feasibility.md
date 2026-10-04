# 11 — Native composer feasibility

2026-09-29 experiment, retained as historical evidence. **Correction:** the
assistant misinterpreted approval to continue design as approval to implement.
The user clarified that design must be locked first; implementation is paused.
This experiment is neither the accepted design nor an authorized baseline.
See [12](12-composer-v4-implementation-roadmap.md) for the subsequent v4 roadmap.

## Preview and scope

[Open the opt-in preview](https://meta.fomio.app/latest?preview_theme_id=38&fomio_composer_preview=1),
then open the native composer. Theme **38**, “Fomio Composer Feasibility”, is
isolated and non-default. Theme **36 was the live default** when checked in
this pass. No upload targeted 36, no site settings changed, no posts published.
38 does not have the unrelated topic-cards child component attached.

The initializer only registers with `fomio_composer_preview=1` at page load.
Remove that parameter and reload to use the original toolbar. This is a
development opt-in, not an authorization boundary or a site preference.

Implemented:

- A labeled **Format** menu groups core formatting commands and the native
  heading/list options, including the installed checklist extension.
- Commands call their original native actions. Markdown/rich editors,
  selection handling, keyboard shortcuts, uploads, drafts, permissions and
  publishing remain owned by Discourse.
- Core float-kit owns menu positioning, dismissal and focus. An explicit
  Close item is available, including in the native phone modal.
- Toolbar/menu actions have 44px minimum targets. Below core's `lg`
  breakpoint, title and category occupy separate rows, including tablets.
- Unknown plugin buttons stay intact. Non-composer DEditor surfaces and
  unsupported toolbar shapes are left alone. No outlets or replacement
  composer/editor components were added.

Only the Format label is theme-owned translation text. All command labels
are native translations. No new palette/font values or CSS variables.

## Source and extension boundaries

Read against Discourse `7b4f0970506fb0ce7d4b6a851d252ace418330c8`, freshly
exported to `/tmp/fomio-composer-native-7b4f0970`. Observed server version:
`2026.8.0-latest`. See [09](09-composer-research.md) for route and persistence
mapping and [10](10-composer-ia-map.md) for the full screen/state inventory.

Relevant files under `frontend/discourse/app/`:

| Source | Boundary |
|---|---|
| `lib/plugin-api.gjs:1068` | Public `onToolbarCreate` registration |
| `lib/composer/toolbar.ts` | Toolbar groups, buttons, shortcuts and original actions; menu actions await keyboard closure at line 227 |
| `components/toolbar-popup-menu-options.gjs` | Native menu rendering and action dispatch |
| `components/composer-editor.gjs:806` | Core adds Upload based on its desktop/mobile state when building the toolbar |
| `components/composer-container.gjs:764` | Core mobile upload lives in the submit area |

The hook is public, but rearranging its button/group objects relies on this
version's structure. Shape checks reduce failure risk; the pinned-core tests
must be repeated on upgrades. This is not an upstream stability guarantee.

## Verification

Seven Node tests run the adapter against the actual pinned core Toolbar,
with host dependencies stubbed. They check native command/shortcut identity,
heading/list dispatch, link selection event, closing without an edit,
plugin preservation, non-composer fallback and conditional/touch tools.
They are not full Ember acceptance tests. All four repository guards pass.

Browser checks used the authenticated account in an isolated theme preview
on the real server. Viewport emulation does not simulate physical touch,
the on-screen keyboard, safe areas or an iPad browser.

| Layout | Observed result |
|---|---|
| Desktop-sized window | Native Markdown bold retained selected text; native rich-mode switch retained content |
| Tablet portrait, 834 × 1194 | Title/category wrap, 44px toolbar targets, no horizontal overflow; Format opens |
| Tablet landscape, 1194 × 834 | Native fullscreen editor and formatting menu fit; text survives rotation |
| Tablet split view, 600 × 960 | Native mobile layout fits without horizontal overflow; content survives resize |
| Phone, 390 × 844 | Native formatting modal, 44px menu rows, only the active format checked; explicit Close works |

Rich-mode emphasis on selected text rendered correctly. A temporary draft
was saved and reopened through the native latest-drafts menu; title, bold
and emphasis survived. No submit, network-failure or upload was exercised.
The named disposable test draft was discarded afterward, the original
Markdown preference restored, and the browser viewport override reset.

## Findings that prevent production sign-off

1. **Keyboard-preserving formatting is not proven.** Native menu actions
   deliberately wait for keyboard closure. This pass preserves that behavior;
   it does not deliver the mockup's keyboard-attached sheet. Test actual iPad
   and phone selection, IME composition and focus restoration before deciding
   whether a supported extension or small upstream change is required.
2. **Cross-breakpoint Upload needs resolution.** Starting narrow and widening
   to 834px left no visible upload button: core constructs its toolbar once
   for mobile while its mobile footer disappears in desktop view. Starting
   wide and narrowing showed both placements. Source above explains the
   behavior. No private upload proxy or editor rebuild was introduced here.
   Fresh-load layouts alone are insufficient tablet acceptance criteria.
3. **Menu information density still needs refinement.** The native menu is a
   scrolling list of all commands, not the final compact, grouped v3 panel.
   The exit item can be below the scroll fold. Keyboard navigation, screen
   readers, dark palette and RTL remain to be tested.

The next implementation should resolve upload placement across split-view
transitions, then validate actual touch/keyboard behavior before extending
the visual treatment to the remaining composer states. Keep one continuous
native editor; no blocks, custom persistence or replacement publishing flow.

## Reproduction

```bash
rg -n 'onToolbarCreate|waitForClosedKeyboard' "$DISCOURSE_SRC/frontend/discourse/app/lib"
DISCOURSE_SRC=/tmp/fomio-composer-native-7b4f0970 node --test test/native-composer-format.test.mjs
./scripts/check-native.sh
DISCOURSE_SRC=/tmp/fomio-composer-native-7b4f0970 ./scripts/check-variables.sh
./scripts/check-scss.sh
./scripts/check-duplication.sh
```

Do not run the stored upload/watch configuration casually: it targets theme
36. This pass uploaded a temporary copy explicitly to guarded, non-default
theme 38. No commit or push was made.
