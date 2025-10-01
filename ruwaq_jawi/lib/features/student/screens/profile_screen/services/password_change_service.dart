import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../widgets/password_change_dialog_widget.dart';
import 'profile_notification_helper.dart';

class PasswordChangeService {
  static void showPasswordChangeDialog(BuildContext context) {
    PasswordChangeDialogWidget.show(
      context,
      onSuccess: () {
        ProfileNotificationHelper.showPasswordUpdateSuccess(context);
      },
      onError: (message) {
        ProfileNotificationHelper.showError(context, message);
      },
    );
  }

  static Future<bool> changePassword(
    BuildContext context, {
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final authProvider = context.read<AuthProvider>();
      return await authProvider.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
    } catch (e) {
      debugPrint('Error changing password: $e');
      return false;
    }
  }

  static String? validatePasswordChange({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (oldPassword.trim().isEmpty) {
      return 'Sila masukkan kata laluan lama';
    }

    if (newPassword.trim().isEmpty) {
      return 'Sila masukkan kata laluan baru';
    }

    if (newPassword.length < 6) {
      return 'Kata laluan baru mestilah sekurang-kurangnya 6 aksara';
    }

    if (newPassword != confirmPassword) {
      return 'Kata laluan baru dan pengesahan tidak sepadan';
    }

    if (oldPassword == newPassword) {
      return 'Kata laluan baru mestilah berbeza daripada kata laluan lama';
    }

    return null;
  }
}