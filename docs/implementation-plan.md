# Native MVP implementation plan

Accepted by the user on 2026-10-03. Implement against the final Claude project export in `design/snapshots/2026-10-03`, with the native adaptation described below.

## Accepted decisions

- Native SwiftUI, iOS/iPadOS 26+, one Latest Home feed.
- Four destinations: Home, Communities, Notifications, Me; independent navigation stacks. Search is a utility and Create is a composer action.
- Nested replies are required for release: three visible levels, collapsed child branches, focused deeper-thread navigation, independent root/child pagination, exact-post context. No chronological fallback if deployed support is absent.
- Local account-isolated text/context drafts, deleted on explicit sign-out. No server synchronization or offline sending queue.
- Fixture-backed Home → Community → Discussion → Composer is the first delivery. Complete fixture Search, Notifications, profiles, Saved and Drafts alongside the integration foundation.
- Preserve Fomio purple/white and AMOLED tokens, genuine wordmark, semantic system typography, native glass navigation/controls and flat content. iPad content is capped at 620pt.

## Build sequence and gates

1. Preserve versioned design source and photo provenance. Generate the Xcode application/unit/UI test project. Add domain identities, repository protocols, fixtures, environment configuration and native navigation.
2. Implement the native core slice and nested adaptation. Prove writing, destination, attachment exit warnings, local recovery, authentication return intent, and independent submission outcomes.
3. Recheck Discourse revision; inspect routes, controllers/services, serializers, authorization and request specs. Record contract evidence, sanitize fixtures, implement adapters and browser user-key authorization with Keychain storage. Live verification requires supplied site configuration, user scopes/callback and test accounts.
4. Complete supporting MVP routes and accessibility/device acceptance. Browser mockup QA is not native acceptance. Release additionally requires nested capability, live contracts, signing and production link configuration.

## Behavior and interfaces

Distinct category/topic/post IDs and post numbers; logical routes carry topic ID plus optional post number. Repository interfaces cover feeds, communities, discussion roots/children/context, Likes, search, notifications/read state, profiles, bookmarks, posting/reconciliation and uploads. Fixture and Discourse adapters share these interfaces. No administrator key.

Composer uses native raw text and a single photo. New discussions need a title and permitted community; replies retain parent identity. Draft/upload/authorization/submission states are independent. Keep editing / Keep draft / explicit Discard; unfinished photo warning before saving and Add again / Continue without photo on resume. Background autosave is best effort and failures are shown.

A confirmed publish removes the local draft and opens its destination in the originating tab. Pending review retains a locked record. Unconfirmed submission is locked, Check again does not infer success from matching text, and manual retry requires a duplicate warning. Authentication never posts or automatically applies Like/Save.

## Validation

Unit tests for protected local persistence, account isolation/sign-out, save errors, termination during submitting, upload exit recovery, pending/unconfirmed locks, publication/origin, guest intent, threading/pagination/exact context, relative-root links, DTO optional permissions and fixture search. UI tests for the core reply/draft flow, guest authorization, notification #14 and unconfigured live mode. Native QA covers light/dark, Dynamic Type, accessibility settings, keyboard, narrow phone, iPad resizing, RTL and assistive navigation. Live anonymous/member/denied/revoked/rate-limit checks remain deployment-gated.

## Deferred

Hot/tracked feeds, notification-level controls, private messages, chat, AI, advanced settings/activity, formatting modes, editing posts, server drafts, push transport and production universal-link entitlements. English copy uses localization-ready literals. No invented site URL, enabled plugins, credentials or signing team. The production bundle identifier `com.fomio.mobile` comes from the existing App Store Connect record.
