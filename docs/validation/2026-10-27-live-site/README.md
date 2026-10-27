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

## Signed-in checks — same day

The owner signed in on the iPhone 17 simulator with a test account through the app's own sign-in (the site's login page in the authentication sheet); the app stored a per-user API key in the simulator keychain. No password was entered by automation.

| Check | Result |
| --- | --- |
| `testStoredMemberReadPermissionsSavedAndNotifications` | **Pass.** Current user, communities, theme, profile, saved, notification history and totals, latest feed, safety session (`canIgnoreUsers`) and report reasons on recent posts by others. |
| `testConsolidatedCategoryHierarchyAndNativeIdentity` with the stored key | Pass (after a rate-limited first attempt, below). |
| `testApprovedTemporaryTopicRepliesSaveAndCleanup` (`FOMIO_LIVE_WRITE_TESTS=1`, owner-approved) | **Pass.** In Fomio › Experiments & Ideas (54) only: created topic 2593, a reply to #1, a nested reply quoting it, threaded readback, bookmark save and removal, then deleted the topic. A guest read of `/t/2593.json` returns 404 afterwards (staff can still see it as deleted). |
| Signed-in Home | Loads (`03-iphone17-signed-in-home.png`). Simulator taps did not reach the tab bar, so Me, Notifications and the composer were not driven in the UI. |

**The test account is staff.** The write test runs only for an administrator or moderator (an ordinary author cannot delete a replied-to topic, so cleanup would not be guaranteed), and it ran. These results therefore show the staff path. Ordinary-member permissions and denials remain unverified.

**Rate limit.** The first signed-in run failed both live tests with `rateLimited` (HTTP 429): the per-key user API limit is 50 requests per minute and 4,000 per day by default (`GlobalSetting.max_user_api_reqs_per_minute`/`_per_day`, `lib/auth/default_current_user_provider.rb`), and the directory test alone walks every root community's feed. Spaced runs pass. Normal browsing should stay below the minute limit; the app maps 429 to its rate-limited state (contract-tested).

## Open

- **Blank first frame.** A Debug build on the Duo simulator shows a blank window for several seconds after launch, with sample content as well as live, so it is not network-bound. A sample showed the main thread inside `dyld_sim` waiting on debugger image notifications. Not established for a Release build or hardware; measure there before treating it as an app defect.
- **Ordinary-member evidence** (restricted categories, denied create, report/flag limits) needs a non-staff account. Uploads, likes and editing were not exercised.
