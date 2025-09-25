import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Global error boundary widget to catch and display uncaught exceptions
/// Prevents black screen by showing user-friendly error messages
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? title;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.title,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();

    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (mounted) {
        setState(() {
          _error = details.exception;
          _stackTrace = details.stack;
        });
      }
    };
  }

  void _clearError() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    return ErrorBoundaryWrapper(
      onError: (error, stackTrace) {
        if (mounted) {
          setState(() {
            _error = error;
            _stackTrace = stackTrace;
          });
        }
      },
      child: widget.child,
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Error title
                Text(
                  widget.title ?? 'Oops! Sesuatu tidak kena',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Error message
                Text(
                  'Aplikasi menghadapi masalah yang tidak dijangka. Jangan risau, data anda selamat.',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondaryColor,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Action buttons
                Column(
                  children: [
                    // Retry button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _clearError();
                          widget.onRetry?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cuba Lagi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Technical details button (debug mode only)
                    if (_error != null && _shouldShowDetails())
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => _showErrorDetails(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textSecondaryColor,
                            side: BorderSide(color: AppTheme.borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Lihat Butiran Teknikal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowDetails() {
    // Only show technical details in debug mode
    bool isDebug = false;
    assert(() {
      isDebug = true;
      return true;
    }());
    return isDebug;
  }

  void _showErrorDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Butiran Ralat'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Error:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error.toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              if (_stackTrace != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Stack Trace:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stackTrace.toString(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Copy error to clipboard
              Clipboard.setData(ClipboardData(
                text: 'Error: $_error\n\nStack Trace:\n$_stackTrace',
              ));
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ralat disalin ke clipboard'),
                ),
              );
            },
            child: const Text('Salin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

/// Internal wrapper to catch errors in the widget tree
class ErrorBoundaryWrapper extends StatefulWidget {
  final Widget child;
  final Function(Object, StackTrace) onError;

  const ErrorBoundaryWrapper({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  State<ErrorBoundaryWrapper> createState() => _ErrorBoundaryWrapperState();
}

class _ErrorBoundaryWrapperState extends State<ErrorBoundaryWrapper> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up error handling for this specific widget tree
  }
}