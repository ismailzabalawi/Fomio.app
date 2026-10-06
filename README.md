# Fomio iOS

A native SwiftUI client for Fomio, backed by Discourse APIs. This project is separate from the Discourse backend and web theme.

The native iOS/iPadOS 26+ SwiftUI MVP has an Xcode project, live Discourse screens, protected local drafts, fixture previews, and automated tests. The configured site's guest/member read contracts and an approved temporary posting round trip have been exercised; release gates remain in the validation documents.

## Run

Open `Fomio.xcodeproj`, select the Fomio scheme and an iOS 26+ simulator. Debug uses the live site configured in `project.yml` (`https://meta.fomio.app`); pass `--fixture` for the explicitly labeled fictional fixture preview. Pass `--guest` to exercise sign-in return intent or `--live --unconfigured` to prove the unconfigured-live screen. Release never falls back to fixture content.

`project.yml` is the XcodeGen source (`xcodegen generate`). Build and test with Xcode, or `xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,name=<installed device>' test`. Simulator builds use ad hoc signing so protected Keychain storage can be tested; distribution signing remains unconfigured. The `FomioBaseURL`, `FomioAuthCallback` and `FomioUserAPIScopes` Info values are set under the app target's `info.properties`. The bundle identifier is `com.fomio.mobile` and the app icon is `Fomio/Resources/AppIcon.icon`; configure distribution signing before release. Never commit credentials.

## Documentation

- [Documentation map](docs/README.md): reading order and authority.
- [Architecture](docs/architecture.md): ownership, identities, navigation, repositories and storage.
- [Development guide](docs/development-guide.md): build, fixtures, configuration and troubleshooting.
- [Flows and recovery](docs/flows-and-recovery.md): authentication, threading, drafts, photos and write outcomes.
- [Release readiness](docs/release-readiness.md): coverage, missing resources and acceptance procedure.
- [Accepted implementation plan](docs/implementation-plan.md)
- [Implementation and validation status](docs/implementation-status.md)
- [Latest composer snapshot](docs/design/snapshots/2026-10-04/README.md) and [previous design snapshot](docs/design/snapshots/2026-10-03/README.md)
- [Native editor validation and release gates](docs/editor-validation.md)

- [Project foundation](docs/project-foundation.md): accepted direction, navigation, journeys, and open decisions.
- [Current Fomio information architecture](docs/information-architecture.md): consolidated navigation, screen map, composer states, journeys, and implementation boundaries.
- [Discourse API reference](docs/discourse-api-reference.md): local source reference, initial route inventory, and contract verification workflow.
- [Imported IA maps and build guide](docs/ia-build-guide.md): prior Fomio route maps, Discourse research, composer states, and their application to this SwiftUI client.
- [Finalized MVP design handoff](docs/design/mvp-design-handoff.md): launch scope, iOS 26+ Liquid Glass direction, Fomio colors, mockup references, browser verification and remaining native/integration checks. This narrows the broader IA for launch.

Read these documents before implementation. Record newly verified backend behavior and product decisions alongside the relevant documentation.
