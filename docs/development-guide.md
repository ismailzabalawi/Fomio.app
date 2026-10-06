# Development and integration guide

## Local prerequisites

Use Xcode with the iOS 26 SDK or newer and an installed iOS 26+ simulator. The checked-in project was generated with XcodeGen and validated using Xcode 27, iOS 26.1 simulators. XcodeGen is needed only when regenerating `Fomio.xcodeproj` from `project.yml`. The app has no external Swift package dependencies.

Open `Fomio.xcodeproj`, select the **Fomio** scheme, choose a simulator, then Run or Test. Application, unit-test and UI-test targets are included. The deployment target is 26.0 and supports both device families. Bundle identifier is `com.fomio.mobile`, the App Store Connect record (app 6759279998) previously used by the Expo app at `/Volumes/Develop/Projects/Fomio/apps/mobile`; this build replaces it. The app icon is the Icon Composer bundle `Fomio/Resources/AppIcon.icon`, adapted from that app's `assets/Fomio-logo.icon` with the swoosh recoloured to the accent `#5B3FD6`; its dark and tinted variants are unchanged.

```sh
xcodegen generate
xcodebuild -project Fomio.xcodeproj -scheme Fomio \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Use an installed simulator name in place of the example. Native tests use ad hoc simulator signing because Keychain access needs a signed executable. Distribution signing is unconfigured. Simulator UDIDs in validation evidence are machine-local and should not be copied as portable configuration.

## Environment selection

| Build/input | Behavior |
| --- | --- |
| Debug, missing configuration | Explicitly labeled fictional fixture preview |
| Debug `--fixture` | Force fixtures even if live settings exist |
| Debug `--live` | Use live adapter; missing/invalid configuration shows configuration unavailable |
| Debug `--live --unconfigured` | Ignore bundled live settings to show the configuration-unavailable screen |
| Debug, valid configuration, no override | Live adapter |
| Release | Live adapter only; no fixture fallback |

Use only one environment override; the current code gives `--fixture` precedence if both flags are passed. Rebuild after changing Info settings. A missing configuration screen is intentional, not a network error.

Set arguments in the Xcode scheme’s Run action. Fixture account defaults to `jonah.w` (Jonah Wells), matching the MVP mockup seed; `--guest` starts without member identity. Guest authorization is simulated by the sign-in sheet's Sign in button. This creates no real user key.

| Argument | Purpose |
| --- | --- |
| `--post-outcome published|pending|rejected|expired|unconfirmed` | Select fixture posting outcome |
| `--upload-fails` | Simulate photo failure at 60% |
| `--dark` | Override to dark appearance |
| `--accessibility-text` | Override Dynamic Type to accessibility3 |
| `--rtl` | Override layout direction |
| `--preset <name>` | Debug only. Open a Screen Pack state: `communities`, `findcom`, `findnone`, `community`, `subcommunity`, `empty`, `denied`, `discussion`, `offline`, `linked`, `unavailable`, `search`, `notifications`, `me`, `profile`, `saved`, `drafts`, `draftlost`, `resumelost`, `chooser`, `reply`, `quote`, `newtopic`, `uploading`, `uploadfail`, `rejected`, `expired`, `unconfirmed`, `pending`, `loading`. Combine with `--guest`, `--dark` or `--accessibility-text`. |
| `--ui-testing` | Enables isolated fixture draft directory when a valid namespace is supplied |

UI tests set `FOMIO_UI_TEST_NAMESPACE` to a fresh UUID and use `Application Support/UITests/<UUID>`. Normal drafts use `Application Support/Drafts`. Use simulator container inspection for debugging; local records may contain private writing. Do not commit credentials or real private draft data.

Me → Fixture scenarios provides outcome, offline, upload-failure and nested-capability controls. Diagnostics are available only when a fixture service is active. Fixture mutations disappear when the service restarts; local drafts survive. The sample photo action is for fixture recovery testing. “Add sample drafts” stores the mockup's reply, new-discussion and photo-not-included drafts for the current account.

## Live configuration

Values live under the app target's `info.properties` in `project.yml`; XcodeGen writes them to `Fomio/Info.plist`, which Xcode merges with the generated plist. Custom keys set as `INFOPLIST_KEY_*` build settings are silently dropped, so do not move them back there. Rerun `xcodegen generate` after changing them.

| Key | Current value (observed 2026-10-04) |
| --- | --- |
| `FomioBaseURL` | `https://meta.fomio.app` (no relative URL root) |
| `FomioAuthCallback` | `fomio://auth_redirect` (present in `allowed_user_api_auth_redirects`) |
| `FomioUserAPIScopes` | `read,write,notifications,session_info` (all in `allow_user_api_key_scopes`) |

See the deployment snapshot in [discourse-api-reference.md](discourse-api-reference.md). Sign-in callback delivery is not yet exercised.

Do not substitute an assumed production hostname. Callback configuration is not complete simply because the string parses: app URL types/entitlements, deployed allowlists and callback delivery must be configured and tested. The app’s `.onOpenURL` handles logical destinations; production universal-link entitlements and association files are not provided.

Browser authorization requests a per-user key using an RSA public key, nonce and client identity. The encrypted callback is validated/decrypted, then the current user is resolved before restoring intent. Scope approval, anonymous access, login-required sites, expiry/revocation and rate limits must be exercised against real deployment accounts. No administrator key is appropriate for this client.

## Debugging common states

| Observation | Interpretation / next check |
| --- | --- |
| Configuration needed | Check all three Info settings and selected environment; do not replace with fake community data |
| Authorization required | Sign in, verify approved scopes/callback and current-user access; Post still requires an explicit tap |
| Discussion unavailable / 404 | Check target visibility, deletion and nested setting; 404 alone cannot distinguish them |
| Photo failed | Writing is preserved; retry/remove photo before posting, or keep without photo |
| Couldn’t save on this device | Check local storage/protection; do not report success or submit while persistence preparation fails |
| Post not confirmed | Keep record locked; check destination and reconciliation evidence before manual duplicate-risk retry |
| Pending review | Keep local non-postable record; do not claim the post is publicly available |
| Keychain test failure | Confirm simulator executable uses ad hoc signing; do not bypass storage with embedded credentials |

## Backend review workflow

Treat `/Volumes/Develop/Projects/Dicourse` as read-only reference. Check `git rev-parse HEAD` before relying on recorded contracts, then review route, controller/service, serializer, Guardian, user-key scope and request-spec evidence. Update [API reference](discourse-api-reference.md) with the revision and status. Backend changes require a separate authorized task.

Source review, tests against local sanitized transport stubs, and live verification are different evidence. Local Swift contract tests do not run the backend’s request specs. Run live acceptance only after the deployment resources in [release readiness](release-readiness.md) are supplied.


### Category/topic redesign preview — 2026-10-06

Use `--fixture --preset communities`, `community`, `subcommunity`, `discussion` or `linked` to inspect the compact category/topic layouts. Add `--teal-theme` for a fictional alternate scheme, `--dark`, `--accessibility-text` or `--rtl` for adaptation checks. The fixture taxonomy is unchanged; its category identity markers are fictional. Live mode fetches default site schemes from `/site.json`; scheme/theme member preference precedence remains unresolved. Palette failures retain fallback/current styling and do not grant permissions.

### Opt-in live API checks (2026-10-06)

`LiveDiscourseTests` uses the app's supplied configuration and, for member reads, its existing per-user Keychain credential. Enable `FOMIO_LIVE_READ_TESTS=1` in the test runner environment for guest/member integration reads. `FOMIO_LIVE_UI_TESTS=1` enables the native category → child → About → topic journey. XcodeBuildMCP's `testRunnerEnv` passes these values; ordinary runs skip the live checks. Run anonymous and member batches separately and leave at least a minute between them: Discourse returned real 429s during burst integration runs. Deployed limit values are not established. `FOMIO_CLEANUP_TOPIC_IDS` optionally supplies comma-separated exact recorded test IDs for read-only Saved/guest cleanup verification.

The write test additionally requires explicit user authorization for its temporary topic/replies and `FOMIO_LIVE_WRITE_TESTS=1`. Run only that test when exercising approved writes; do not enable write checks for unattended regression runs. It checks the precise approved category, per-user authentication and cleanup authority first, records the exact created topic ID, removes its bookmark and deletes its topic, and checks guest unavailability. A publication with uncertain outcome is never retried automatically. Recovery using `FOMIO_PREVIOUS_TEST_TOPIC_ID` is restricted to the exact ID recorded by a prior approved test; it must not be filled from a search/title guess. See the [live API verification record](discourse-api-reference.md#live-categorytopic-api-validation--2026-10-06).
