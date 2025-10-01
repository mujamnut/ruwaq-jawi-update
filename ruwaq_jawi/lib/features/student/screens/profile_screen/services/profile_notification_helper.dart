import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';

class ProfileNotificationHelper {
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
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

  static void showNameUpdateSuccess(BuildContext context) {
    showSuccess(context, 'Nama berjaya dikemaskini');
  }

  static void showPasswordUpdateSuccess(BuildContext context) {
    showSuccess(context, 'Kata laluan berjaya dikemaskini');
  }
}