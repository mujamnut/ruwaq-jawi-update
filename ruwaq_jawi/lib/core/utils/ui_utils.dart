import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Utility class for common UI building patterns
class UIUtils {
  /// Create a loading widget
  static Widget buildLoading({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  /// Create an error widget with retry button
  static Widget buildError(
    String message, {
    VoidCallback? onRetry,
    String retryText = 'Cuba Lagi',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert01,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: Text(retryText)),
            ],
          ],
        ),
      ),
    );
  }

  /// Create an empty state widget
  static Widget buildEmptyState({
    required String message,
    String? subtitle,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon ?? HugeIcons.strokeRoundedFolder01,
              color: Colors.grey,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onAction, child: Text(actionText)),
            ],
          ],
        ),
      ),
    );
  }

  /// Create a standard app bar with transparent background
  static PreferredSizeWidget buildAppBar({
    required String title,
    List<Widget>? actions,
    bool showBackButton = true,
    VoidCallback? onBackPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return AppBar(
      title: Text(title),
      backgroundColor: backgroundColor ?? Colors.transparent,
      foregroundColor: foregroundColor ?? Colors.black,
      elevation: 0,
      leading: showBackButton
          ? IconButton(
              onPressed: onBackPressed,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                color: Colors.black,
              ),
            )
          : null,
      actions: actions,
    );
  }

  /// Create a standard card with consistent styling
  static Widget buildCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    VoidCallback? onTap,
    Color? color,
    double? borderRadius,
  }) {
    final cardChild = Container(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Card(
        color: color ?? Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12),
        ),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius ?? 12),
                child: cardChild,
              )
            : cardChild,
      ),
    );
  }

  /// Create a standard search bar
  static Widget buildSearchBar({
    required TextEditingController controller,
    required VoidCallback onChanged,
    String hintText = 'Cari...',
    VoidCallback? onClear,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: const HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: Colors.grey,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    if (onClear != null) onClear();
                  },
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: Colors.grey,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Create a standard list tile
  static Widget buildListTile({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  /// Create a standard section header
  static Widget buildSectionHeader({
    required String title,
    String? subtitle,
    Widget? trailing,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Create a standard button
  static Widget buildButton({
    required String text,
    required VoidCallback onPressed,
    bool isPrimary = true,
    bool isLoading = false,
    EdgeInsetsGeometry? padding,
    double? borderRadius,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? Theme.of(GlobalKey().currentContext!).primaryColor
              : Colors.grey[100],
          foregroundColor: isPrimary ? Colors.white : Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(text),
      ),
    );
  }

  /// Show a standard snackbar
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show a standard dialog
  static Future<bool?> showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Ya',
    String cancelText = 'Batal',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? ElevatedButton.styleFrom(backgroundColor: Colors.red)
                : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Create a standard RefreshIndicator wrapper
  static Widget buildRefreshable({
    required Widget child,
    required Future<void> Function() onRefresh,
  }) {
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}

/// Mixin for screens with common state handling
mixin ScreenStateMixin<T extends StatefulWidget> on State<T> {
  /// Safe setState that checks if widget is still mounted
  void safeSetState(VoidCallback callback) {
    if (mounted) {
      setState(callback);
    }
  }

  /// Show error snackbar
  void showError(String message) {
    if (mounted) {
      UIUtils.showSnackBar(context, message, isError: true);
    }
  }

  /// Show success snackbar
  void showSuccess(String message) {
    if (mounted) {
      UIUtils.showSnackBar(context, message);
    }
  }

  /// Show loading dialog
  void showLoadingDialog({String? message}) {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(message ?? 'Memuat...'),
              ],
            ),
          ),
        ),
      );
    }
  }

  /// Hide loading dialog
  void hideLoadingDialog() {
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
