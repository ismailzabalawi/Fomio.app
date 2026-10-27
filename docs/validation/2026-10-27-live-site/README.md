# Live site guest checks — 2026-10-27

Site: `https://meta.fomio.app` (the app's existing `FomioBaseURL`, confirmed by the owner on 2026-10-27). Branch `claude/duo-system-bar`. Guest (signed-out) reads only: no sign-in, no writes, no backend change.

## Site

- `GET /about.json`: Discourse `2026.10.0-latest`, title "Fomio", 2,504 topics. `site.json` and `latest.json` return 200.
- Root communities: General (Interesting Finds 11, Introductions 42), Science & Health, Business & Finance, Politics, Sports, Lifestyle, Entertainment & Arts, Gaming, Technology, Fomio (Bug Reports, Announcements, Dev Blog, Feature Requests, Help & Support, Experiments & Ideas 54, Knowledge Base), Off-topic Discussions.

## Results

| Check | Device | Result |
| --- | --- | --- |
| Unit target with `FOMIO_LIVE_READ_TESTS=1` | iPhone 17 / iOS 27.0 | 218 run, 0 failures, 2 skipped. `testAnonymousSiteDirectoryFeedsAndExactTopicContracts` and `testConsolidatedCategoryHierarchyAndNativeIdentity` pass live. Skipped: the stored-member read and the approved temporary-topic write test (no member credential, no write approval). |
| `testCaptureLiveStoreScreenshots` (`FOMIO_STORE_CAPTURES=1`) | iPhone 17, iPad Pro 11-inch (M5) | Pass |
| `testLiveCategoryChildAboutAndTopicNavigation` (`FOMIO_LIVE_UI_TESTS=1`) | iPhone 17, iPad | **Failed first, test fixed, then pass on both.** The test looked for `community-about` directly; About lives in the feed's options menu (`feed-options`), as the fixture tests already expect. |
| Live launch, Open pose, two panes | iPhone Duo / iOS 27.1 | Live feed, category icons, thumbnails and the selected discussion load in the Duo layout. |

## Defects found and fixed

- **Lightbox details shown as body text.** Uploaded images are cooked inside `div.lightbox-wrapper > a.lightbox`, with a `<div class="meta">` holding the file name and size (`1280×720 63.3 KB`). The web shows it only on hover; the native parser turned it into a paragraph under every uploaded image. `HTMLContent.blocks` now drops `div.meta`. The same post had `alt=""`, which became an empty accessibility label; an empty alt now falls back to "Community photo". Unit test `testLightboxMetaIsNotBodyText` uses the observed markup. Before/after: `01-duo-open-live-lightbox-before.png`, `02-duo-open-live-lightbox-fixed.png`.

## Open

- **Blank first frame.** A Debug build on the Duo simulator shows a blank window for several seconds after launch, with sample content as well as live, so it is not network-bound. A sample showed the main thread inside `dyld_sim` waiting on debugger image notifications. Not established for a Release build or hardware; measure there before treating it as an app defect.
- **Member checks** (sign-in, saved, notifications, permissions) and **any write** (reply, topic, upload, like) need an ordinary member account and explicit approval. Only an administrator account was previously available; the administrator account must not be used as member evidence.
