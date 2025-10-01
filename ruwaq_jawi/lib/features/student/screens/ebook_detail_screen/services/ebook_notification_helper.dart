import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookNotificationHelper {
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static void showSaveSuccess(BuildContext context, bool isSaved) {
    showSuccess(
      context,
      isSaved
          ? 'Successfully add to favorite'
          : 'Successfully remove to favorite',
    );
  }

  static void showDownloadSuccess(BuildContext context) {
    showSuccess(context, 'E-book berjaya diunduh');
  }
}