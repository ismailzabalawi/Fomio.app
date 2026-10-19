# Independent Compact/Cards review — 2026-10-15

Reviewed main commit `302973709b77b89c5272593cd45b1e7fea442d0e`, including the card/list implementation in `9a56c71`, against `docs/design/topic-card-prototype.md`. Claude's separate localization session was still running in `.claude/worktrees/fomio-localization-impl-48ecab`; this review did not modify its code or interrupt its work.

## Actionable finding

**P2 — Recover image loading after a transient failure.** `Fomio/Features/TopicCard.swift:40` retains `mediaFailed` as view state. Lines 45–47 remove every media source once it is true, and line 206 sets it on any AsyncImage failure. There is no reset when the topic's image URL changes or the feed refreshes. `FeedView` identifies each TopicCard by the same topic ID, so refreshing a still-visible topic preserves the failed flag. A temporary offline failure, or a subsequently corrected image URL, therefore stays text-only until the view is recreated. Reset failure when a source changes and provide an explicit retry/refresh path for the same source; cover offline failure → restored connection → refresh and failed URL → replacement URL.

This finding is established by source/state lifecycle review. It was not reproduced in a new Simulator run. The existing failed-media UI case proves fallback to text but does not exercise recovery.

## Evidence and limits

Inspected `TopicCard.swift`, the feed appearance/anchor implementation in `FeedView.swift`, media/title adapter changes, `TopicCardTests.swift`, `FeedAppearanceUITests.swift`, the design brief and recorded validation report. Visually inspected the recorded live guest Cards capture on iPhone 16e, Arabic RTL Cards capture on iPhone 17 Pro, and dark accessibility-size Cards capture on iPad. The captures show readable adaptive layouts and distinct category/topic presentation; they do not prove current runtime interaction or physical-device accessibility.

The implementation's recorded results are 87 unit tests with four live opt-ins skipped, 33 UI tests with one live opt-in skipped, and six iPad feed appearance tests passing. Those results were read from the existing report rather than independently rerun in this review. Claude's active localization work may alter visible strings, accessibility and layout; a follow-up review must inspect its final diff and relevant final test evidence. Avoid overlapping builds or Simulator automation with that active session.

A follow-up named “Review Claude localization and feeds” was created in this chat to check progress every 15 minutes, stay quiet while unchanged, and review the finished localization implementation for feed regressions. It should deactivate after reporting the completed review or a concrete blocker.
