# Fomio documentation map

Current native baseline: 2026-10-03. The fixture MVP is implemented; live release remains gated. These documents are checked-in developer/product handoff, not additional deployment authorization.

## Reading order

1. [Implementation status](implementation-status.md): what is delivered, actual test evidence and practical limits.
2. [Accepted plan](implementation-plan.md): decisions, MVP boundaries and required release gates.
3. [Architecture](architecture.md): composition, source ownership, domain identity, navigation/state, transport and persistence.
4. [Development guide](development-guide.md): prerequisites, build/test, development scenarios and pending configuration.
5. [Flows and recovery](flows-and-recovery.md): observable screen/auth/thread/composer/draft/photo behavior.
6. [API reference](discourse-api-reference.md): source revision, evidence, response shapes and unresolved deployment contracts.
7. [Release readiness](release-readiness.md): automated coverage, native/live acceptance and required resources.

## Design and historical references

- [MVP design handoff](design/mvp-design-handoff.md) defines the narrowed launch direction.
- [Versioned source export](design/snapshots/2026-10-03/README.md) records provenance, original hashes, Review Index repair and photo licenses. Native typography uses system fonts; exported Lora is reference-only.
- [Native captures](validation/2026-10-03/README.md) record simulator layouts; [browser evidence](design/mockup-verification.json) is design evidence only.
- [Project foundation](project-foundation.md) records origin and accepted decision updates.
- [Broader IA](information-architecture.md) retains future/historical routes; Hot, tracking, messaging and editing there are not launch commitments.
- [IA build guide](ia-build-guide.md) and [imported web references](references/fomio-web/README.md) preserve prior research. Imported source wording remains unchanged and requires fresh verification before reuse.

## Authority and maintenance

The user’s accepted decisions determine scope. Current implementation guides describe inspected code; historical maps describe proposals. Discourse determines live permissions/content/posting rules. Route existence, source review, sanitized adapter tests and deployed verification are distinct statuses.

When changing behavior, update the corresponding guide and implementation status. When changing an adapter, recheck backend revision and update API evidence/assumptions. Record validation with device/OS, selected tests, result artifacts and limitations. Do not overwrite original exports/imports or promote browser/fixture evidence to native/live acceptance. Do not document credentials or invent deployment resources.
