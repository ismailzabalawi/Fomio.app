# Project foundation

Recorded: 2026-10-02.

Design update: 2026-10-03. The [finalized MVP design handoff](design/mvp-design-handoff.md) defines the launch subset and iOS 26+ Liquid Glass direction. The broader navigation inventory below remains future product context; advanced feeds, tracking, activity, messages and settings are not all MVP commitments. A native fixture build and source-informed integration foundation are now implemented; see [implementation status](implementation-status.md). Live deployment verification remains pending.

## Direction and provenance

The user established this as a new iOS project following the [shared planning conversation](https://chatgpt.com/s/cx_6abf647c22f881918938bba2ac244169). The chosen direction is a native, API-driven SwiftUI experience with freedom to design the presentation. Discourse owns the community data and rules.

The earlier hybrid web-view proposal was superseded by the native client direction. The information architecture below is a planning baseline, with backend support to be verified before implementation.

## Historical broader information architecture

The [current Fomio IA map](information-architecture.md) consolidates the latest reference updates into the native iOS planning baseline. Its proposed treatments and open decisions are identified explicitly; API and deployment verification remain separate.

Prior Fomio IA, route maps, composer research, and acceptance records are now available through the [IA build guide](ia-build-guide.md). Use them as traceable reference material under this project's native SwiftUI direction; historical web implementation and deployment observations require fresh verification.

| Entry | Purpose |
| --- | --- |
| Home | Cross-community feed; Hot and Latest; tracked-community filter |
| Communities | Directory, subcommunities, and tracked communities |
| Notifications | Replies, mentions, and supported account notifications |
| Me | Profile, activity, bookmarks, private messages, and settings |
| Search | Globally accessible discussions, communities, and people search |
| Create | Separate action opening a composer sheet; preselect current community when appropriate |

Community and discussion are working UI labels for Discourse categories and topics. Categories and subcategories should share a screen system. New discussions, replies, and edits should share composer components while retaining their different requirements.

## Product principles

- Support open reading where site permissions allow it.
- Let members choose tracking; no mandatory interest picker.
- Preserve tracking and watching as distinct Discourse behaviors; avoid an ambiguous Join action.
- Use Communities, Hot, and Latest for discovery.
- Treat private messages and chat as separate features. Chat scope remains undecided.
- Advanced moderation and administration may initially remain on the web.

## Journeys to prove

1. Browse as a guest, open a discussion, choose Reply, authenticate, and return to the intended reply.
2. Browse a community, set its tracking or notification level, and return to a tracked Home feed.
3. Create a discussion, choose a community, attach media, publish, and open the resulting discussion.
4. Open a notification or shared link at the exact discussion or reply.
5. Recover a draft after backgrounding or connectivity loss; retry without creating duplicate posts.

Design loading, empty, error, and access-denied states alongside normal screens. Account for closed/deleted discussions and composer upload, validation, pending moderation, failure, and recovery states.

## Resources and decisions still needed

- Running Discourse base URL and its relationship to the reference checkout.
- Custom backend plugins and deployment alignment. The web/theme reference checkout is now known: `/Volumes/Develop/Projects/Rebuilding Discourse/fomio-web`; see the IA build guide for provenance.
- Enabled plugins, relevant site settings, and test-account access.
- Authentication callback configuration and permitted user API scopes.
- iOS/iPadOS 26.0 deployment is configured; the production bundle identifier is `com.fomio.mobile` (existing App Store Connect record); signing remains pending.
- Production link resources remain pending. Push transport, chat and server draft synchronization are deferred from the accepted MVP.

The fixture core journey and supporting MVP screens are implemented. Next work is deployment-specific verification and native release acceptance, as tracked in [release readiness](release-readiness.md).

## Accepted implementation decisions — 2026-10-03

The user approved [the implementation plan](implementation-plan.md): Latest-only Home, required nested replies with three visible levels and focused deeper threads, fixture-first delivery, local account-isolated drafts with deletion on explicit sign-out, and no server draft sync. The native launch subset in the design handoff supersedes broader navigation proposals above.
