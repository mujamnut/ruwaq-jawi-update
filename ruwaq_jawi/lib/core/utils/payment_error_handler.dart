import 'package:flutter/material.dart';

/// Enhanced error handling untuk payment system
/// Provides user-friendly error messages dan recovery actions
class PaymentErrorHandler {
  /// Handle payment errors dengan appropriate user messages
  static String getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return 'Masalah sambungan internet. Sila semak sambungan anda dan cuba lagi.';
    }
    
    if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return 'Sesi anda telah tamat. Sila log masuk semula.';
    }
    
    if (errorString.contains('forbidden') || errorString.contains('403')) {
      return 'Anda tidak mempunyai kebenaran untuk melakukan tindakan ini.';
    }
    
    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'Maklumat pembayaran tidak dijumpai. Sila cuba lagi.';
    }
    
    if (errorString.contains('server error') || errorString.contains('500')) {
      return 'Masalah pada pelayan. Sila cuba lagi sebentar.';
    }
    
    if (errorString.contains('toyyibpay')) {
      return 'Masalah dengan sistem pembayaran. Sila cuba lagi atau hubungi support.';
    }
    
    if (errorString.contains('plan not found')) {
      return 'Plan langganan tidak dijumpai. Sila pilih plan yang sah.';
    }
    
    if (errorString.contains('user not authenticated')) {
      return 'Sila log masuk untuk meneruskan pembayaran.';
    }
    
    if (errorString.contains('payment verification')) {
      return 'Tidak dapat mengesahkan status pembayaran. Sila cuba semak semula.';
    }
    
    if (errorString.contains('subscription already active')) {
      return 'Anda sudah mempunyai langganan aktif untuk plan ini.';
    }
    
    // Default error message
    return 'Ralat tidak dijangka berlaku. Sila cuba lagi atau hubungi support jika masalah berterusan.';
  }

  /// Get error severity level
  static ErrorSeverity getErrorSeverity(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return ErrorSeverity.warning;
    }
    
    if (errorString.contains('unauthorized') || 
        errorString.contains('forbidden')) {
      return ErrorSeverity.critical;
    }
    
    if (errorString.contains('not found')) {
      return ErrorSeverity.warning;
    }
    
    if (errorString.contains('server error')) {
      return ErrorSeverity.critical;
    }
    
    return ErrorSeverity.error;
  }

  /// Show error dialog dengan recovery actions
  static void showErrorDialog(
    BuildContext context, 
    dynamic error, {
    String? title,
    List<PaymentErrorAction>? actions,
    VoidCallback? onDismiss,
  }) {
    final errorMessage = getErrorMessage(error);
    final severity = getErrorSeverity(error);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getErrorIcon(severity),
              color: _getErrorColor(severity),
              size: 24,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                title ?? _getErrorTitle(severity),
                style: TextStyle(
                  color: _getErrorColor(severity),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(errorMessage),
            
            if (severity == ErrorSeverity.critical) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, 
                         color: Colors.red.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Jika masalah ini berterusan, sila hubungi support untuk bantuan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: _buildDialogActions(context, error, actions, onDismiss),
      ),
    );
  }

  /// Show error snackbar untuk quick notifications
  static void showErrorSnackBar(
    BuildContext context, 
    dynamic error, {
    Duration? duration,
    SnackBarAction? action,
  }) {
    final errorMessage = getErrorMessage(error);
    final severity = getErrorSeverity(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(severity),
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                errorMessage,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(severity),
        duration: duration ?? Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: action,
      ),
    );
  }

  /// Build action buttons for error dialog
  static List<Widget> _buildDialogActions(
    BuildContext context,
    dynamic error,
    List<PaymentErrorAction>? customActions,
    VoidCallback? onDismiss,
  ) {
    final actions = <Widget>[];
    
    if (customActions != null && customActions.isNotEmpty) {
      for (final action in customActions) {
        actions.add(
          action.isPrimary
              ? ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: action.color ?? Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(action.label),
                )
              : TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    action.onPressed?.call();
                  },
                  child: Text(
                    action.label,
                    style: TextStyle(color: action.color),
                  ),
                ),
        );
      }
    } else {
      // Default actions based on error type
      final errorString = error.toString().toLowerCase();
      
      if (errorString.contains('network') || errorString.contains('connection')) {
        actions.addAll([
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could trigger a retry action here
              onDismiss?.call();
            },
            child: Text('Cuba Lagi'),
          ),
        ]);
      } else if (errorString.contains('unauthorized')) {
        actions.addAll([
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', 
                (route) => false,
              );
            },
            child: Text('Log Masuk'),
          ),
        ]);
      } else {
        actions.add(
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: Text('OK'),
          ),
        );
      }
    }
    
    return actions;
  }

  /// Get appropriate icon for error severity
  static IconData _getErrorIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return Icons.warning_amber;
      case ErrorSeverity.critical:
        return Icons.error;
      case ErrorSeverity.error:
      default:
        return Icons.error_outline;
    }
  }

  /// Get appropriate color for error severity
  static Color _getErrorColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.critical:
        return Colors.red;
      case ErrorSeverity.error:
      default:
        return Colors.red.shade700;
    }
  }

  /// Get appropriate title for error severity
  static String _getErrorTitle(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return 'Amaran';
      case ErrorSeverity.critical:
        return 'Ralat Kritikal';
      case ErrorSeverity.error:
      default:
        return 'Ralat';
    }
  }
}

/// Error severity levels
enum ErrorSeverity {
  warning,  // Can continue with caution
  error,    // Standard error, can retry
  critical, // Serious error, may need support
}

/// Custom error action for dialogs
class PaymentErrorAction {
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? color;

  const PaymentErrorAction({
    required this.label,
    this.onPressed,
    this.isPrimary = false,
    this.color,
  });
}

/// Utility extension for easy error handling
extension PaymentErrorHandling on BuildContext {
  void showPaymentError(
    dynamic error, {
    String? title,
    List<PaymentErrorAction>? actions,
    VoidCallback? onDismiss,
    bool useDialog = true,
  }) {
    if (useDialog) {
      PaymentErrorHandler.showErrorDialog(
        this, 
        error, 
        title: title, 
        actions: actions, 
        onDismiss: onDismiss,
      );
    } else {
      PaymentErrorHandler.showErrorSnackBar(this, error);
    }
  }
}
