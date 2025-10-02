import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

/// Widget yang rebuild automatically bila connectivity status berubah
///
/// Usage:
/// ```dart
/// NetworkAwareBuilder(
///   online: (context) => OnlineContent(),
///   offline: (context) => OfflineContent(),
/// )
/// ```
class NetworkAwareBuilder extends StatelessWidget {
  final WidgetBuilder online;
  final WidgetBuilder? offline;
  final bool showOfflinePlaceholder;

  const NetworkAwareBuilder({
    super.key,
    required this.online,
    this.offline,
    this.showOfflinePlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, child) {
        if (connectivity.isOnline) {
          return online(context);
        }

        if (offline != null) {
          return offline!(context);
        }

        if (showOfflinePlaceholder) {
          return const _DefaultOfflinePlaceholder();
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget yang hanya show content bila online
///
/// Usage:
/// ```dart
/// OnlineOnly(
///   child: VideoPlayer(),
///   offlinePlaceholder: OfflineMessage(),
/// )
/// ```
class OnlineOnly extends StatelessWidget {
  final Widget child;
  final Widget? offlinePlaceholder;
  final bool showDefaultPlaceholder;

  const OnlineOnly({
    super.key,
    required this.child,
    this.offlinePlaceholder,
    this.showDefaultPlaceholder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline) {
          return child;
        }

        if (offlinePlaceholder != null) {
          return offlinePlaceholder!;
        }

        if (showDefaultPlaceholder) {
          return const _DefaultOfflinePlaceholder();
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget yang hanya show content bila offline
///
/// Berguna untuk offline-only features atau messages
class OfflineOnly extends StatelessWidget {
  final Widget child;

  const OfflineOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        return connectivity.isOffline ? child : const SizedBox.shrink();
      },
    );
  }
}

/// Widget untuk feature yang require internet with elegant handling
///
/// Shows loading state while checking connectivity
/// Shows offline state if no internet
/// Shows content if online
class NetworkRequiredWidget extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? offlineWidget;
  final String? offlineMessage;
  final VoidCallback? onRetry;

  const NetworkRequiredWidget({
    super.key,
    required this.child,
    this.loadingWidget,
    this.offlineWidget,
    this.offlineMessage,
    this.onRetry,
  });

  @override
  State<NetworkRequiredWidget> createState() => _NetworkRequiredWidgetState();
}

class _NetworkRequiredWidgetState extends State<NetworkRequiredWidget> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    setState(() => _isChecking = true);

    final connectivity = context.read<ConnectivityProvider>();
    await connectivity.refreshConnectivity();

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          );
    }

    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline) {
          return widget.child;
        }

        return widget.offlineWidget ??
            _NetworkOfflineWidget(
              message: widget.offlineMessage,
              onRetry: () {
                _checkConnectivity();
                widget.onRetry?.call();
              },
            );
      },
    );
  }
}

/// Default offline placeholder with icon and message
class _DefaultOfflinePlaceholder extends StatelessWidget {
  const _DefaultOfflinePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tiada Sambungan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ciri ini memerlukan sambungan internet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Consumer<ConnectivityProvider>(
              builder: (context, connectivity, _) {
                return TextButton.icon(
                  onPressed: () => connectivity.refreshConnectivity(),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Cuba Lagi'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline widget with custom message and retry
class _NetworkOfflineWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const _NetworkOfflineWidget({
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off,
                size: 50,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada Sambungan Internet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message ??
                  'Ciri ini memerlukan sambungan internet. Sila sambung ke WiFi atau data selular.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Cuba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show connection status indicator
class ConnectionStatusIndicator extends StatelessWidget {
  final bool showWhenOnline;

  const ConnectionStatusIndicator({
    super.key,
    this.showWhenOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        if (connectivity.isOnline && !showWhenOnline) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: connectivity.isOnline ? Colors.green : AppTheme.errorColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                connectivity.isOnline ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                connectivity.isOnline ? 'Online' : 'Offline',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
