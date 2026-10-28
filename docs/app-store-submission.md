# App Store submission preparation

Prepared 2026-10-18 (Asia/Amman). **Build 7 is Ready for Review in a draft submission; final Submit for Review has not been clicked.** This is the current submission checklist; historical upload evidence remains in [release readiness](release-readiness.md). This document records evidence; it does not itself authorize a public release.

## Release identity

| Field | Value |
| --- | --- |
| App | Fomio |
| App Store Connect record | 6759279998 (existing record; recorded by earlier uploads) |
| Bundle / team | `com.fomio.mobile` / `LK9253R3XB` |
| Prepared version / build | 0.8.0 (7) |
| Platforms | iPhone and iPad, iOS/iPadOS 26+ |
| Backend | `https://meta.fomio.app`, reconfirmed by the user in this task |
| Authentication | Browser authorization, per-user API key; callback `fomio://auth_redirect` |

The callback scheme is now registered in `project.yml` and generated Info.plist. Me exposes account settings, privacy, terms and About/contact without requiring sign-in for policies. Native account deletion follows the Expo app's Discourse DELETE endpoint, with server permission/identity checks, explicit username and destructive confirmation, confirmed-success decoding and local sign-out. Password collection and Expo's ignored confirmation 404 are not copied: reference `UsersController` does not put `destroy` behind `check_confirmed_session`. This is source-verified, not a destructive deployed test.

## Submission status

| Gate | Current evidence and next action |
| --- | --- |
| Public policies | **Updated live with owner authorization.** Privacy includes native data/key/draft/photo handling, server searches/activity, account deletion and owner-supplied 90-day log retention. Terms now covers the official app, removes template text/date tokens and unfinished jurisdiction/arbitration passages. Company The ZincBuild and empty jurisdiction settings preserved. Actual server log rotation is not independently verified. |
| Support | **Fixed.** About contact now opens `mailto:support@fomio.app`; native Me and deletion help use the same address. Mailbox delivery/monitoring is an owner operational responsibility and was not tested by sending mail. |
| Report and block | **Implemented and tested.** Post More (•••) → Report post uses current dynamic flag IDs and server permissions, custom required details and confirmed response. Block member uses server Ignore Forever, verifies persisted ignored_users, hides loaded content and supports profile More → Block member and Me → Blocked members → Unblock. Phone and iPad fixture UI pass. Actual moderator receipt and member Ignore round trip still require a test member; no real report/block was sent. |
| Deletion | **Implemented; live permission fixed.** Owner approved raising self-delete post threshold. Server rejected 2,147,483,647; saved its supported maximum **2,000,000,000**. Admin and externally managed restrictions remain. No real account was deleted. |
| Member safety availability | **Live settings saved:** `trust_level_0` added to reporting and Ignore groups while preserving existing groups. Guardian still controls target restrictions, rate limits and current eligibility. |
| Privacy labels | **Published in Connect.** Eight categories, linked, not tracking: Name, Email Address, User ID, Other User Content, Photos or Videos, Search History, Product Interaction, Other Data Types (request/IP data). App functionality for all; Search History additionally analytics because server search logging is enabled. Old audio and unlinked declarations corrected. Manifest matches these categories. Website Google Analytics wording/configuration preserved; no native analytics/ads SDK. |
| Store copy | **Saved in Connect draft:** version 0.8.0, native description/promo/keywords/What's New/review notes; existing secure review credentials/contact and manual release mode preserved. No review submission. |
| Live acceptance | **Member authentication and reads passed after user sign-in.** Current-user identity, Saved, notifications, profiles, feeds, dynamic report options, can_ignore_users and account-deletion eligibility endpoint all passed with the real per-user key. No report, Ignore mutation or account deletion was sent. TestFlight and physical-device acceptance remain. Real Photos, posting/reply, moderator delivery and destructive disposable deletion need appropriate member/device acceptance. |
| Screenshots and devices | **Required assets complete in Connect:** 3 native iPhone 1206×2622 captures and 2 native iPad 2064×2752 captures. Old optional Expo iPhone sets removed from the version (retained in Asset Library). Disk blocker resolved after owner freed space; iPad capture passed. [Asset inventory](app-store-assets/0.8.0/README.md). Physical-device VoiceOver, real Photos and final TestFlight acceptance remain unverified. |

## Draft listing copy

Review this copy against the final accepted feature set before entering it in Connect.

- **Name:** Fomio
- **Subtitle:** Communities worth reading
- **Keywords:** community,discussions,writing,forums,topics,blogging
- **Support URL:** `https://meta.fomio.app/about` 
- **Privacy URL:** `https://meta.fomio.app/privacy` 
- **Suggested category:** Social Networking; confirm the existing listing's positioning.
- **Promotional text:** Find your communities, follow thoughtful discussions, and share your perspective with Fomio for iPhone and iPad.

**Description**

Find your communities and make room for thoughtful conversation.

Browse discussions, explore communities, and follow replies in a clear, native experience for iPhone and iPad. Search for topics, save posts for later, and return to the conversations that matter to you.

Write a new discussion or join an existing one. Format your words, add photos, preview your writing, and keep unfinished drafts on your device.

Reading follows each community's access rules. Sign in to post, save discussions, and see your replies and mentions. Drafts stay on the device where you wrote them and are removed when you sign out.

**What's New**

A rebuilt native experience for iPhone and iPad, with community browsing, nested replies, discussion search, Saved posts, and a visual editor with photos, previews and local draft recovery.

## Review notes draft

Fomio is a native client for the community at https://meta.fomio.app. Public content can be browsed without signing in where site permissions allow. Member actions use browser authorization and a per-user key; authorization returns to the app. Signing in never posts automatically.

To review: browse Home or Communities, open a discussion, choose Reply and sign in using the dedicated reviewer account entered in App Store Connect's review-account fields. Return to the app and explicitly choose Post to publish. Saved posts and device-local drafts are in Me. Search opens from the toolbar. Me also provides policies/contact and account deletion. Deletion is permanent; supply a separate disposable reviewer account if testing it is necessary.

Report or block from the More (•••) button beside the post number on another member’s post, or by long-pressing the post. Block is also in the More menu on a member’s profile. Manage ignored members in Me → Blocked members. Me → Delete account checks eligibility and requires username plus destructive confirmation. Admin/externally managed accounts show support. Keep review credentials in Connect’s secure fields and verify that the review account can sign in before review.

## Packaging checks and final handoff

Run `python3 scripts/submission_preflight.py` from the project root. For an archive also run:

```sh
python3 scripts/submission_preflight.py --app .build/submission-0.8.0-7/Fomio.xcarchive/Products/Applications/Fomio.app
```

The command checks packaged configuration, callback registration, privacy manifest, version, icon metadata and transport settings. Passing is not a claim about moderation, deletion eligibility, signatures, policy content or App Review acceptance. Check the signed archive's entitlements and provisioning separately. Final test/archive evidence is recorded in release readiness.

Local distribution IPA prepared: `.build/submission-0.8.0-7/export/Fomio.ipa`. Signature verification and packaged preflight passed; distribution `get-task-allow` is false. [Validation evidence](validation/2026-10-18-submission/README.md). Build 7 uploaded successfully, completed processing and is selected/saved in the 0.8.0 version draft. No review submission occurred.

After blockers pass: finish metadata/privacy/rating, capture assets, validate the signed archive in Xcode/Connect, upload a unique build, complete TestFlight acceptance, select the processed build and review account, and submit for review. Public release timing must be chosen explicitly in Connect.

## Apple references checked

- [Review guidelines](https://developer.apple.com/app-store/review/guidelines/): UGC controls, contact details, completeness, privacy and accurate metadata.
- [Account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/): deletion initiation and associated data; a general email request is not sufficient for ordinary apps.
- [App Privacy details](https://developer.apple.com/app-store/app-privacy-details/): include developer and third-party collection, purposes and linkage.
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype): app-only UserDefaults reason `CA92.1`, verified via Apple's documentation JSON.
- [Submission SDK requirements](https://developer.apple.com/news/upcoming-requirements/), [screenshots](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) and [age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating): recheck against Connect's current requirements; do not infer a rating from the forum's minimum age.
- [HIG settings](https://developer.apple.com/design/human-interface-guidelines/settings/): keep account/support options in Me; retain feed appearance beside the feed it affects.


## Submission-state permission

After the required native screenshot slots were filled and build 7 was selected, automatic approval review rejected clicking **Add for Review**: this changes Connect submission state and preparation alone does not explicitly authorize it. The action was not performed or bypassed. Owner approval is needed for that exact next step. Physical/TestFlight acceptance and reviewer-account access remain unverified; do not equate a prepared Connect draft with completed App Review.


### Owner-approved Add for Review completed

On 2026-10-18 at 08:02 Asia/Amman, after explicit owner approval for **Add for Review**, Connect accepted version 0.8.0 / build 7 and displays **Ready for Review**. Its Draft Submission panel shows **Item Ready to Submit**, iOS App 0.8.0, 0.8.0 (7), and a separate **Submit for Review** button. That final button was not clicked; no Waiting for Review status is claimed. Existing manual release remains selected. The earlier automatic-approval block is resolved for Add for Review only. Confirmation.

## Branding and ASO preparation — 18 October 2026

Prepared a [branded English review set](app-store-assets/0.8.0/branded-en-US/README.md) from the accepted v0.2 identity: three 1206×2622 iPhone frames, two 2064×2752 iPad frames, metadata candidates and an editable renderer. Local pixel/dimension/profile/text-fit checks pass. This set and its copy have **not** been applied to Connect, and this preparation does not change the build/submission state above. Cloud outputs remain in the [Claude App Store review](https://claude.ai/design/p/b56face5-bd5a-4fc5-9732-1804845867e4?file=App+Store+Review.dc.html); cloud download failures led to separately verified local reproductions. The source content is weak for conversion, especially political headlines, no visible replies and welcome-post shortcode rendering. Prefer better native content captures before replacing the current listing.
