# Discourse integration plan — draft, 2026-10-04

## Aim and authority

Connect the existing native SwiftUI client to `https://meta.fomio.app` in small, verifiable slices. Discourse remains authoritative for content, access, posting rules and moderation. The imported Expo and web-theme records are research leads, not instructions or proof of the current deployment. The accepted native scope in [implementation-plan.md](implementation-plan.md) governs this work; this plan does not add Hot, chat, private messages, editing or push.

The local reference at `/Volumes/Develop/Projects/Dicourse` is `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` as rechecked on 2026-10-04, with only an unrelated untracked note. The deployed site was previously recorded at `7b4f0970506fb0ce7d4b6a851d252ace418330c8`; source and deployment are different revisions. Recheck both before a contract change. Do not edit the backend as part of this client integration.

## Current starting point

`Fomio/Data/DiscourseService.swift` and `Network.swift` already implement source-informed adapters. `Authentication.swift` implements browser per-user authorization and Keychain storage. Guest app requests to feeds, categories, nested discussions, search and profiles succeeded on the live site; those observations and remaining caveats are in [discourse-api-reference.md](discourse-api-reference.md). On 2026-10-04, the pre-consent error was traced to unescaped `+` in the public-key query value and fixed in `Network.swift`; a native attempt now reaches the login page. Member consent, callback and identity remain unverified. Admin browser access cannot substitute for an ordinary member's permissions. No member write or private-read contract is live verified.

## Work sequence and exit evidence

| Stage | Work | Exit evidence |
| --- | --- | --- |
| 1. Complete user-key issuance | The pre-consent query, incoming-URL fallback and wrapped Base64 callback defects are fixed in the client. Have a non-admin member complete login and consent on the rebuilt app, then verify OAEP decryption, Keychain storage and current-user lookup. Exercise cancellation, denial, revocation and expiry. | A per-user key reaches Keychain; `GET /session/current.json` resolves that member; canceled, denied, revoked and expired flows return to a safe state. No key or callback payload is recorded in docs or test fixtures. |
| 2. Lock read contracts | For each existing adapter, record route, controller/service, serializer, Guardian/scope and request-spec evidence at the current reference revision. Replay sanitized guest and member responses against the deployed site, including permission denial, pagination and optional fields. | Home/categories, nested roots/children/context, search, profiles, Saved and notifications have a field-level contract table and app screenshots or test results. Explicitly distinguish a public 200 from member access. |
| 3. Exercise member actions | With a disposable member account and agreed test destination, test Like/unlike, bookmark/unbookmark, notification read state, upload, new discussion and nested reply. Use server-returned IDs and permissions; test 403/404/422/429, moderation queue and account revocation. Do not retry an uncertain post automatically. | Each action has request/response shape, successful and denied outcome, and a clean-up record for disposable content. Draft, upload and posting recovery match the existing app state model. |
| 4. Reconcile uncertain writes | Determine whether an exact server identifier or other reliable evidence can resolve a timed-out create. Test pending-author visibility separately. If no reliable contract exists, keep `Check again` unresolved and require the existing duplicate-warning manual retry. | A documented positive reconciliation rule with a live test, or an explicit unresolved release risk; never match on title/body text alone. |
| 5. Native acceptance | Run the live guest/member journeys on phone and iPad, including sign-in return intent, exact-post links, account switch/sign-out, RTL/large text, photo failures, offline recovery and disabled/denied nested behavior. | Record device/OS, site commit/settings, test account role, sanitized evidence and failures in the API reference and release-readiness guide. Fixture and browser mockup checks do not count as live native acceptance. |

Implement one vertical slice at a time. The first useful slice is guest Home → Community → nested Discussion, then member sign-in → return to the same reply intent, then one controlled reply. Search, notifications and Saved follow once identity and permission handling are proven. Keep plugin composer controls disabled until a normal member's live capability is established.

## Authentication feature packet

**Goal:** Give a member a scoped key through Discourse's browser consent flow so the app can act as that member.

**Entry Point:** `GET /user-api-key/new` and `POST /user-api-key` in `config/routes.rb`, handled by `app/controllers/user_api_keys_controller.rb` (`new`, `create`).

**Client Trigger:** Native `AuthenticationService.signIn()` in `Fomio/Data/Authentication.swift`; the old Expo client is only a reference.

**Server Path:** `UserApiKeysController#new` calls `user_api_key_authorization_model`, which checks required params, registered client constraints, allowed scopes, public key/padding and redirect before login or consent. `#create` issues a key and encrypts the callback payload through `UserApiKey::DeviceAuth::Crypto`. `UserApiKey` stores a hash of the key and checks active/revoked state.

**Data Map:** `db/structure.sql` tables `user_api_keys` (`user_id`, `user_api_key_client_id`, `key_hash`, `revoked_at`, `expires_at`, `last_used_at`), `user_api_key_clients` (`client_id`, `public_key`, `auth_redirect`, `application_name`) and `user_api_key_scopes` (`user_api_key_id`, `name`); associations are in `app/models/user_api_key.rb` and `user_api_key_client.rb`.

**Permissions:** `UserApiKeysController#validate_params`, `#validate_auth_redirect` and `#meets_tl?` apply scope, redirect and group rules; `UserApiKey#allow?` enforces route scope after issuance. The deployed allowlists include the app callback and requested scopes. The earlier generic error was caused by the client sending an unescaped `+` in its public key; the fixed native request reaches login. Member consent and issued-key permissions remain unverified.

**Async Side Effects:** Scheduled key cleanup exists in `app/jobs/scheduled/clean_up_unused_user_api_keys.rb` and `clean_up_user_api_keys_max_life.rb`. No issuance-time job is established by this review.

**Realtime Side Effects:** Unknown; no MessageBus contract is required for this browser issuance slice.

**Serializer/JSON Contract:** The consent page is rendered by `UserApiKeysController#render_user_api_key_authorization`; successful `#create` returns an RSA-encrypted callback payload containing a key and nonce. `spec/requests/user_api_keys_controller_spec.rb` covers ready/generic states, redirect checks, scopes and OAEP. The app requests `read,write,notifications,session_info` and `padding=oaep` from `AuthenticationService.signIn()`.

**Tests:** `spec/requests/user_api_keys_controller_spec.rb` asserts invalid RSA keys become `generic_error`, invalid padding is rejected, disallowed redirects are rejected, scopes are enforced, and OAEP encrypts a decryptable payload. Native `FomioTests` contract tests cover the client in isolation; a completed deployed consent has not passed.

**Safest Extension Plan:** Use the existing Discourse flow with no backend extension. A theme can style consent but cannot change key issuance rules. If a new API capability proves necessary, propose a plugin with request specs before considering core; no such change is justified yet.

**Verification Steps:**

1. `rg -n 'user-api-key/new|user-api-key' /Volumes/Develop/Projects/Dicourse/config/routes.rb`
2. `rg -n 'def user_api_key_authorization_model|def validate_params|def validate_auth_redirect|def parse_public_key!' /Volumes/Develop/Projects/Dicourse/app/controllers/user_api_keys_controller.rb`
3. `rg -n 'generic_error|OAEP|redirect|scopes' /Volumes/Develop/Projects/Dicourse/spec/requests/user_api_keys_controller_spec.rb`
4. Run the focused backend request spec in a configured backend test environment, then repeat the browser authorization with a disposable member and inspect the matching Admin → Logs entry. Record only the exception class and sanitized request facts.

## Evidence ledger to maintain

For each endpoint, add a row to [discourse-api-reference.md](discourse-api-reference.md) with reference and deployed commits, HTTP method/path, source identifiers (route, controller/service, Guardian, serializer, spec), guest/member/denied responses, pagination/error behavior, app test, and status: `source identified`, `contract reviewed`, `live verified`, or `blocked`. Record settings only when actually observed on the site. Sanitize response fixtures; never store user keys, private posts, cookies, callback payloads or administrator credentials.

The pre-consent failure is diagnosed in the [API reference](discourse-api-reference.md): a live anonymous A/B request showed the raw `+` form fail and the `%2B` form pass, and the fixed native request reached login. The remaining gate is a non-admin member completing consent and the callback. The admin error-log UI had no retained match because the relevant trace is an Info event gated by a verbose logging setting; no site setting was changed.
