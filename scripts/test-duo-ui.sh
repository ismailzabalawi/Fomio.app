#!/bin/bash
# Runs the iPhone Duo UI regression set: the UI tests that passed on iPhone Duo / iOS 27.1.
# Usage: scripts/test-duo-ui.sh [result-bundle-path]
# Requires Xcode 27.1 at /Applications/Xcode.app and a booted iPhone Duo simulator.
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DUO_UDID="${DUO_UDID:-24097A57-4311-4B00-9D83-F032E00F3962}"
RESULT_BUNDLE="${1:-${TMPDIR:-/tmp}/fomio-duo-ui-$(date +%Y%m%d-%H%M%S).xcresult}"

cd "$(dirname "$0")/.."

xcodebuild test \
  -project Fomio.xcodeproj \
  -scheme Fomio \
  -destination "platform=iOS Simulator,id=${DUO_UDID}" \
  -resultBundlePath "$RESULT_BUNDLE" \
  -only-testing:FomioUITests/FomioUITests/testSwipeDismissalProtectsChangedWriting \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testCommunityChooserKeepsMatchingParentAndCancelKeepsScope \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testCommunityChooserAccessibilityAudit \
  -only-testing:FomioUITests/FomioUITests/testComposerSelectionFormattingKeepsActionsReachable \
  -only-testing:FomioUITests/FomioUITests/testLargestTextSelectionFitsBar \
  -only-testing:FomioUITests/FeedAppearanceUITests/testSwitchKeepsMidFeedTopicAnchorBothDirections \
  -only-testing:FomioUITests/FeedAppearanceUITests/testCardsSurviveCategoryAndTopicBack \
  -only-testing:FomioUITests/FeedAppearanceUITests/testSwitchKeepsPaginationErrorAndLoadedPages \
  -only-testing:FomioUITests/FeedAppearanceUITests/testCardCasesOmitAbsentFieldsAndKeepSeparateTargets \
  -only-testing:FomioUITests/FeedAppearanceUITests/testDarkAccessibilityTextAndRightToLeftCaptures \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testEmptySearchCancelKeepsMidFeedPosition \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testInlineSearchFailureAccessibilityAudit \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testDarkArabicLargeTextErrorAndCancelStayReachable \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testFailedCommunityListKeepsFilterAndManualRetryRecovers \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testGroupedFailureIsInlineAndManualRetryRecovers \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testOutsideScopeReturnRetainsExactSearchReply \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testPaginationFailureRetainsEarlierPageAndRetriesNextPage \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testPublicLinkRendersExactReplyOutsidePreviousCommunity \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testPullAtTopRevealsSearchWithoutReservedRow \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testRefreshFailureKeepsPreviousResultsUntilManualRetry \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testResolvedCurrentCommunityMatchesWithoutContradictoryEmptyState \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testSavedReplyOpensExactPostContext \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testScopeChangeKeepsQueryAndNeverShowsOldScopeResults \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testScopedAccessFailureRemovesRowsAndKeepsRecoveryVisible \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testSearchFieldGrowsAtAccessibilityTextSize \
  -only-testing:FomioUITests/AdaptiveReadingUITests/testSearchStartsCollapsedAndCancelReturnsToFeed \
  -only-testing:FomioUITests/FeedAppearanceUITests/testMenuSwitchesBothWaysAndPersistsAcrossRelaunch \
  -only-testing:FomioUITests/FomioUITests/testCategoryDarkLargeTextAndThemeReflow \
  -only-testing:FomioUITests/FomioUITests/testCategoryDirectoryExpansionAboutAndChildCreate \
  -only-testing:FomioUITests/FomioUITests/testCommunityFieldSearchesInPlace \
  -only-testing:FomioUITests/FomioUITests/testComposerCatalogueQuickQuoteAndSearchRecovery \
  -only-testing:FomioUITests/FomioUITests/testComposerMoreRefreshesUndoRedoAfterEachAction \
  -only-testing:FomioUITests/FomioUITests/testDarkAccessibilityComposerRemainsReachable \
  -only-testing:FomioUITests/FomioUITests/testDirectoryFilterKeepsAncestorAndQueryAfterBack \
  -only-testing:FomioUITests/FomioUITests/testFailedPhotoKeepWarnsAndResumeRetainsWriting \
  -only-testing:FomioUITests/FomioUITests/testFloatingBarTurnsBlockIntoHeadingAndInserterCancelKeepsCaret \
  -only-testing:FomioUITests/FomioUITests/testGuestSignInDoesNotPost \
  -only-testing:FomioUITests/FomioUITests/testHeadingMenuEnablesVisualInlineFormatting \
  -only-testing:FomioUITests/FomioUITests/testHomeDiscussionReplyAndKeepDraft \
  -only-testing:FomioUITests/FomioUITests/testInserterCancelPreservesHiddenKeyboard \
  -only-testing:FomioUITests/FomioUITests/testKeyboardBarNextAndKeepEditing \
  -only-testing:FomioUITests/FomioUITests/testKeyboardDismissedAndAuthorizationVisibleAfterLongReply \
  -only-testing:FomioUITests/FomioUITests/testKeyboardDismissedAndRejectionVisibleAfterLongReply \
  -only-testing:FomioUITests/FomioUITests/testLiveDoesNotUseFixtureFallback \
  -only-testing:FomioUITests/FomioUITests/testNativeBlockFormAndMarkdownRoundTrip \
  -only-testing:FomioUITests/FomioUITests/testNativeFormattingCaretTypingSurvivesSourceSwitch \
  -only-testing:FomioUITests/FomioUITests/testNotificationTargetsExactReply \
  -only-testing:FomioUITests/FomioUITests/testReportCustomReasonAndBlockThenUnblock \
  -only-testing:FomioUITests/FomioUITests/testRestrictedAccountDeletionExplainsSupportAndCanBeCancelled \
  -only-testing:FomioUITests/FomioUITests/testSearchKeepsQueryAndResultsAfterDiscussion \
  -only-testing:FomioUITests/FomioUITests/testUnconfirmedUIRequiresDuplicateWarning \
  -only-testing:FomioUITests/FomioUITests/testVisualChecklistCanBeCreatedAndCheckedWithoutSource \
  -only-testing:FomioUITests/FomioUITests/testVisualDraftRecoversAfterTerminationWithExactMarkdown \
  -only-testing:FomioUITests/FomioUITests/testVisualHeadingMarkdownPreviewAndReturnPreserveDraft \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testArabicEmojiFormattingAndLosslessModeSwitches \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testCheckedPastePreservesRichMarksAndIsOneUndoAction \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testKeyboardControlsAtAccessibilitySize \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testNativeEditMenuPastePreservesBasicFormattingOnExport \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testTypingUndoThenRedoRestoresArabicAndEmojiReplacement \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testUndoRedoAcrossFormattingModesAndSourceTyping \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testUnsupportedPasteOffersExplicitPlainTextRecovery \
  -only-testing:FomioUITests/RichComposerPrototypeUITests/testUnsupportedSourceIsPreservedAndPlainTypingSurvivesSwitching
