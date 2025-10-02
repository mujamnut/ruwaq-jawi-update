import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// Centralized service untuk handle semua network operations
/// dengan automatic offline detection, retry mechanism, dan error handling
class NetworkService {
  /// Execute a network operation with automatic offline handling
  ///
  /// Returns null if offline, otherwise returns result of operation
  /// Shows offline dialog automatically if needed
  static Future<T?> executeWithConnectivity<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    String? offlineMessage,
    bool showOfflineDialog = true,
    VoidCallback? onOffline,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();

    // Check if offline
    if (connectivity.isOffline) {
      if (showOfflineDialog) {
        await _showOfflineDialog(context, offlineMessage);
      }
      onOffline?.call();
      return null;
    }

    try {
      return await operation();
    } catch (e) {
      // Check if error is due to network issue
      if (_isNetworkError(e)) {
        // Refresh connectivity status
        await connectivity.refreshConnectivity();

        if (connectivity.isOffline && showOfflineDialog && context.mounted) {
          await _showOfflineDialog(context, offlineMessage);
        }
      }
      rethrow;
    }
  }

  /// Execute operation with automatic retry when connection restored
  ///
  /// Will wait for internet connection and retry the operation
  static Future<T?> executeWithRetry<T>({
    required BuildContext context,
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
    String? offlineMessage,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();

    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        // Check if online
        if (connectivity.isOffline) {
          debugPrint(
            '🔄 NetworkService: Waiting for connection (attempt ${attempts + 1}/$maxRetries)',
          );

          // Wait for connection
          await _waitForConnection(connectivity, timeout: retryDelay);

          if (connectivity.isOffline) {
            attempts++;
            if (attempts >= maxRetries) {
              if (context.mounted) {
                await _showOfflineDialog(context, offlineMessage);
              }
              return null;
            }
            continue;
          }
        }

        // Try operation
        return await operation();
      } catch (e) {
        attempts++;
        debugPrint(
          '❌ NetworkService: Operation failed (attempt $attempts/$maxRetries): $e',
        );

        // Check if network error
        if (_isNetworkError(e)) {
          await connectivity.refreshConnectivity();

          if (attempts >= maxRetries) {
            if (context.mounted && connectivity.isOffline) {
              await _showOfflineDialog(context, offlineMessage);
            }
            rethrow;
          }

          // Exponential backoff
          await Future.delayed(retryDelay * attempts);
          continue;
        }

        // Not a network error, rethrow immediately
        rethrow;
      }
    }

    return null;
  }

  /// Wait for internet connection to be available
  static Future<void> _waitForConnection(
    ConnectivityProvider connectivity, {
    Duration? timeout,
  }) async {
    if (connectivity.isOnline) return;

    final completer = Completer<void>();
    late VoidCallback listener;

    listener = () {
      if (connectivity.isOnline && !completer.isCompleted) {
        completer.complete();
        connectivity.removeListener(listener);
      }
    };

    connectivity.addListener(listener);

    try {
      if (timeout != null) {
        await completer.future.timeout(timeout, onTimeout: () {
          connectivity.removeListener(listener);
        });
      } else {
        await completer.future;
      }
    } catch (e) {
      connectivity.removeListener(listener);
      rethrow;
    }
  }

  /// Check if error is network-related
  static bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable');
  }

  /// Show offline dialog
  static Future<void> _showOfflineDialog(
    BuildContext context,
    String? message,
  ) async {
    if (!context.mounted) return;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.cloud_off,
              color: Theme.of(context).colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Tiada Sambungan'),
            ),
          ],
        ),
        content: Text(
          message ??
              'Ciri ini memerlukan sambungan internet. Sila pastikan peranti anda disambungkan ke internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final connectivity = context.read<ConnectivityProvider>();
              await connectivity.refreshConnectivity();

              if (context.mounted) {
                Navigator.of(context).pop();

                if (connectivity.isOnline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Sambungan dipulihkan'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Cuba Lagi'),
          ),
        ],
      ),
    );
  }

  /// Check if device has internet connectivity (quick check)
  static Future<bool> hasConnectivity(BuildContext context) async {
    final connectivity = context.read<ConnectivityProvider>();
    return connectivity.isOnline;
  }

  /// Require internet connection or show dialog
  static Future<bool> requiresInternet(
    BuildContext context, {
    String? message,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();

    if (connectivity.isOffline) {
      await _showOfflineDialog(context, message);
      return false;
    }

    return true;
  }
}
