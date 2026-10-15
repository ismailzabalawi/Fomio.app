# Fomio manual language selection — local independent review complete

Date: 2026-10-15. App worktree: `/Volumes/Develop/Projects/Fomio Swift/.claude/worktrees/fomio-localization-impl-48ecab`, branch `claude/fomio-localization-impl-48ecab`. Initial clean HEAD: `12991de81cf1c92a058bd7d0f4d9f414f455a7f1`. Main was `302973709b77b89c5272593cd45b1e7fea442d0e`; unrelated main work must be preserved.

The request was visibly delivered as Message 7 in the existing Claude Code session `local_4a263497-cb52-4210-9444-c2076fd22f95`. No duplicate app checkout/session was created.

## Independent checks completed

- Local backend reference rechecked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, original checkout unchanged except existing untracked `docs/sidebar-outlet-discovery.md`.
- Anonymous live GET `https://meta.fomio.app/fomio/app-locales/1/index.json` returned HTTP 404 at 17:23 UTC. HTML generator reports deployed `7b4f0970506fb0ce7d4b6a851d252ace418330c8`. Sanitized header/body files: `/private/tmp/fomio-locales-independent.headers` and `.body`. This is a deployment blocker, not a working live contract.
- Native full unit/contract suite: 118 discovered, 114 passed, four live tests skipped, zero failed, iPhone 17 / iOS 26.1, via XcodeBuildMCP. Result: worktree `.build/results/codex-unit.xcresult`. App source is still evolving; final changes require appropriate revalidation.
- Backend plugin independent full suite: 44 examples, zero failures (seed 6424), then final request suite including header regression: 12 examples, zero failures (seed 30796). Logs under worktree `.build/results/codex-backend-rspec.log` and `codex-backend-header-requests.log`.
- Backend maintained English/Arabic catalogs and manifest were JSON-equivalent to app copies at the pre-final snapshot (480 keys). Must recheck after final copy edits.

## Findings sent to Claude

1. Backend advertised complete catalogs after checking key presence only. Require validation of maintained text/kinds/plural forms/placeholders/controls/format/size. Source now implements validator and mutation specs; independent 44-example pass verified.
2. Deployed `7b4f0970` unconditionally adds `X-Discourse-Username` in `ApplicationController#set_current_user_for_logs`; local `d4296c5` restricts this on public responses. A public cacheable plugin response must remove it. Source now strips via prepended after-action, and specs simulate the old callback for 200/304 and assert the callback really set a header before removal. Independent final 12 request tests pass. Claude reported a negative control failure without callback; raw evidence still to inspect.
3. Removed language plus missing/corrupt/incompatible cache falls back to English but notice claimed saved translations were shown. Message 15 visibly received; correction/tests still in progress.

## Remaining work

Additional independent verification after the final missing-cache/list-revalidation fixes:

- iPad Pro 11-inch M5 / iOS 26.1: 33 tests (LocalizationTests + LocalizationCoverageTests + ReviewFixesTests), all passed, no skips. Result: `.build/results/codex-ipad-localization-unit.xcresult`.
- Same iPad: five manual-language UI journeys passed, no skips: Arabic-device/site-Arabic fresh install remains English; explicit Arabic selection persists offline; failed selection preserves English; removed Arabic keeps good cache; removed Arabic without cache shows English honestly. Result: `.build/results/codex-ipad-manual-ui.xcresult`.
- All five attached screenshots were exported to `.build/results/codex-ipad-manual-screenshots/` and inspected. English first-launch picker, RTL cached Arabic picker, failed-selection notice, removed cached Arabic notice and uncached English fallback notice render without clipped controls. Back glyph/side in these captures match the shown interface direction. These are simulator fixtures, not live backend evidence or physical-device VoiceOver/native-speaker approval.
- Claude's first full iPhone run exposed old feed/composer UI tests that expected device language to select Arabic. Correction delivered as Message 17. FeedAppearanceUITests and FomioUITests now explicitly select Arabic for those scenarios. The cached-index removal setup also required explicit list revalidation; `LanguageSettingsView` now calls `revalidateLanguages()` and the fresh-index regression passed in the independent 33-test run.

- Inspect final source, test diffs, final app/backend commits and catalog equivalence.
- Final full iPhone and relevant iPad localization/feed/navigation/media UI evidence; independent targeted UI verification.
- Review updated acceptance/API/deployment docs and distinguish release-only human/device gates.
- Live endpoint deployment and anonymous/member verification remain required before merge. No merge, push, deployment or setting change performed by this reviewer.

## Pending coordination / merge-gate interpretation

- Desktop computer-use temporarily reported that the Mac was locked. The user confirmed unlocking it, and access to the same localization session was restored. Shell-based evidence review continued during the lock. Independent results and the E3 concern were queued as Message 19. No final broad test completion or merge is claimed here.
- The original acceptance E3 was a live non-English interface on a device. A draft edit narrowed it to English listing/any approved language; this was flagged rather than accepted. Claude acknowledged Message 19 and restored E3 to a live non-English interface selected in Me › Language from the deployed endpoint. E3 remains blocked on deployment and the language-enabling decision. Arabic remains unapproved for production; native-speaker review, physical-device accessibility and terminology agreement remain open rather than silently waived.
- Current backend commits: `245a6b63e10` and `6eca1a33a4a`; no push/deployment. All three catalog copies match app JSON after the removed-cache notice change. The app branch remains uncommitted at the initial HEAD in this review snapshot.
- The five independent iPad UI screenshots in this folder are durable copies of the inspected attachments. `reviewed-source-sha256.json` records the source snapshot associated with the independent final iPad tests, for comparison against the eventual app commit.

## Checkpoint at 2026-10-15 21:30 Amman

- App implementation committed as `2dda70b434a8da8f751efd0a0f9ad324ed2ab393`. Every file in the independently tested source hash snapshot still matches; backend en/ar/manifest copies remain JSON-equivalent. Only this independent review directory is untracked.
- Rebuilt targeted iPhone run (`run2-targeted-iphone`) passed the feed appearance and cached-removal cases; the Arabic composer rotation test failed waiting for simulator rotation. Its isolated repeat (`run3-rotation-iphone`) passed (1 test, zero failures); no claim is made that the earlier run passed.
- `final-full-iphone.log` is the final-source broad run, started at 21:18. Still running at this checkpoint with no test failures recorded. Do not confuse it with `run1-full-iphone.log`, the superseded three-failure run. Final iPad broad regression evidence and Claude's final validation record remain pending. No merge.

## Checkpoint at 2026-10-15 21:47 Amman

- Inspected the completed final-source iPhone raw log: native suite 120 tests, four live skips, zero failures; UI suite 52 tests, one live skip, zero failures. All five UI suites passed, including the previously failing feed/composer/removal cases, navigation direction and retained-error/media regression coverage. `final-full-iphone.log` ends with `TEST EXECUTE SUCCEEDED`; result: `.build/results/final-full-iphone.xcresult`.
- The final selected iPad run has started (`final-ipad.log` and `.xcresult`); its completion and Claude's final validation record remain pending. No merge.

## Final local review at 2026-10-15 22:18 Amman

- App implementation `2dda70b434a8da8f751efd0a0f9ad324ed2ab393`; Claude's documentation/evidence commit `5bc788e`. All independently tested source hashes still match. Final app/backend English, Arabic and manifest JSON are equivalent; backend worktree is clean. App diff whitespace check passes.
- Final selected iPad raw log ends with `TEST EXECUTE SUCCEEDED`: 120 unit/contract tests (four live skipped), 25 UI tests (none skipped), zero failures. Suites cover localization, feed appearance, direction/navigation, retained errors and recovered media. This completes the local automated review, together with the independent 33 unit/regression and five UI runs above.
- Reviewed Claude's final validation record and all seven committed iPhone screenshots. They support the documented English default, manual Arabic choice/cache, rejection, removal notices, RTL feed and landscape composer. The earlier failed runs remain disclosed. Five live iPhone checks and four live iPad checks were skipped; simulator fixtures do not satisfy deployment gates.
- The original E3 live non-English gate is restored in the committed acceptance document. E2/E3 remain blocked. Arabic native review, physical-device VoiceOver and terminology agreement remain pending.
- Desktop reinspection failed because the system volume has only about 103 MiB free (`No space left on device`). This does not invalidate the earlier visibly confirmed delivery in the same Claude session or the final raw test evidence. No user files were removed. Freeing system disk space is required before further desktop work.

### Concrete deployment handoff (requires authorization and access)

The reviewed payload is `plugins/discourse-fomio-app-locales` in `/Volumes/Develop/Projects/Dicourse-worktrees/fomio-app-locales`, backend commits `245a6b63e10` and `6eca1a33a4a`. Its README contains the installation and compatibility details. No push or deployment has occurred.

1. Obtain the intended plugin repository destination and authorized deployment access for `meta.fomio.app`; publish the reviewed plugin directory to that repository. Do not publish unrelated backend work.
2. Add that plugin clone to the site's existing `containers/app.yml` `hooks.after_code`, then rebuild the container. No migrations are required. Preserve other hooks/settings.
3. Keep the plugin's separate `fomio_app_locales` allowlist at `en` initially. Do not change web UI or content translation settings.
4. Verify the live anonymous and per-user/member index/catalog responses: 200, matching ETag/conditional 304, public cache policy, no username header or member-specific body, and 404 for disallowed/schema-unsupported catalogs. Re-run against the actual deployed revision, not only the newer backend reference.
5. Obtain native Arabic catalog review before authorization to enable `ar` (or supply another complete reviewed language supported by both app and plugin). Then select that live non-English catalog in Me › Language and verify relaunch/offline behavior on a device. This is the preserved E3 requirement.
6. Reassess E2/E3 from the actual evidence before merging. No merge is authorized by local green tests alone. Human/device release gates remain recorded even after E2/E3 pass.

The heartbeat can stop at this prepared external blocker. Resume when deployment authorization/access, an approved non-English catalog and sufficient system disk space are available.
