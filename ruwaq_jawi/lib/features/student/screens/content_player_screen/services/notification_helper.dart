import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/video_progress_service.dart';

class NotificationHelper {
  // PDF Download Success
  static void showPdfDownloadSuccess(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.downloadSimple(),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            const Text('PDF disimpan untuk akses offline'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // PDF Download Error
  static void showPdfDownloadError(BuildContext context, String error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text('Ralat memuat turun PDF: $error'),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Data Loading Error
  static void showDataLoadingError(BuildContext context, String error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ralat memuat kandungan: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Video Loading Error
  static void showVideoLoadingError(BuildContext context, String error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ralat memuat video: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Resume Video Playback
  static void showVideoResumeSuccess(BuildContext context, int seconds) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(PhosphorIcons.play(), color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              'Meneruskan dari ${VideoProgressService.formatDuration(seconds)}',
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Save/Unsave Video Success
  static void showSaveVideoSuccess(BuildContext context, bool isSaved) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            PhosphorIcon(
              isSaved
                  ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                  : PhosphorIcons.heartBreak(),
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              isSaved
                  ? 'Video episod disimpan'
                  : 'Video episod dibuang dari senarai simpan',
            ),
          ],
        ),
        backgroundColor: isSaved ? AppTheme.primaryColor : Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Save/Unsave Video Error
  static void showSaveVideoError(BuildContext context, [String? error]) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(error != null
                ? 'Ralat: $error'
                : 'Ralat menyimpan video episod'),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Generic Success Message
  static void showSuccess(
    BuildContext context,
    String message, {
    IconData? icon,
    PhosphorIconData? phosphorIcon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (phosphorIcon != null)
              PhosphorIcon(phosphorIcon, color: Colors.white, size: 16)
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 16)
            else
              const Icon(Icons.check_circle, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Generic Error Message
  static void showError(
    BuildContext context,
    String message, {
    IconData? icon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  // Generic Info Message
  static void showInfo(
    BuildContext context,
    String message, {
    IconData? icon,
    PhosphorIconData? phosphorIcon,
    Color? backgroundColor,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (phosphorIcon != null)
              PhosphorIcon(phosphorIcon, color: Colors.white, size: 16)
            else if (icon != null)
              Icon(icon, color: Colors.white, size: 16)
            else
              const Icon(Icons.info, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor ?? Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}