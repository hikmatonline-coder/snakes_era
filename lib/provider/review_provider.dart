import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'ads_provider.dart';

class ReviewProvider extends ChangeNotifier {
  static const String _openCountKey = 'review_app_open_count';
  static const String _hasRatedKey = 'review_has_rated';
  static const String _lastRatedAtKey = 'review_last_rated_at_ms';
  static const int _showEveryNthOpen = 5;
  static const int _daysBeforeRatedUserPrompt = 7;

  final InAppReview _inAppReview = InAppReview.instance;
  bool _isPromptVisible = false;

  /// Called when the app enters foreground (same trigger as app-open ads).
  Future<void> onAppOpen(BuildContext context) async {
    if (_isPromptVisible) return;

    final prefs = await SharedPreferences.getInstance();
    final hasRated = prefs.getBool(_hasRatedKey) ?? false;
    final shouldShow = await _shouldShowReviewPrompt(prefs, hasRated);

    if (!shouldShow) return;

    // Avoid overlapping with the app-open ad.
    await Future.delayed(const Duration(seconds: 2));
    if (!context.mounted) return;

    if (context.read<AdProvider>().isShowingAppOpenAd) return;

    await _showReviewPrompt(context, hasRated: hasRated);
  }

  Future<bool> _shouldShowReviewPrompt(
    SharedPreferences prefs,
    bool hasRated,
  ) async {
    if (hasRated) {
      final lastRatedMs = prefs.getInt(_lastRatedAtKey);
      if (lastRatedMs == null) return false;

      final lastRated = DateTime.fromMillisecondsSinceEpoch(lastRatedMs);
      return DateTime.now().difference(lastRated).inDays >=
          _daysBeforeRatedUserPrompt;
    }

    final openCount = (prefs.getInt(_openCountKey) ?? 0) + 1;
    await prefs.setInt(_openCountKey, openCount);
    return openCount % _showEveryNthOpen == 0;
  }

  Future<void> _showReviewPrompt(
    BuildContext context, {
    required bool hasRated,
  }) async {
    if (_isPromptVisible || !context.mounted) return;
    _isPromptVisible = true;

    final rated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppConstants.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Enjoying ${AppConstants.appName}?',
          style: const TextStyle(
            color: AppConstants.textMain,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Your feedback helps us improve the game. Would you mind rating us?',
          style: TextStyle(color: AppConstants.textWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Not Now',
              style: TextStyle(color: AppConstants.textWhite),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.deepPurpleColor,
              foregroundColor: AppConstants.textMain,
            ),
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );

    _isPromptVisible = false;

    if (rated == true) {
      await _requestReviewAndMarkRated();
    } else if (hasRated) {
      // Already rated before — postpone the next prompt by 7 days.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastRatedAtKey, DateTime.now().millisecondsSinceEpoch);
    }
    // Non-raters: open count already incremented; next prompt on 5th open.
  }

  Future<void> _requestReviewAndMarkRated() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing();
      }
    } catch (e) {
      debugPrint('In-app review failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
    await prefs.setInt(_lastRatedAtKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setInt(_openCountKey, 0);
    debugPrint('User marked as rated — next prompt in $_daysBeforeRatedUserPrompt days');
  }
}
