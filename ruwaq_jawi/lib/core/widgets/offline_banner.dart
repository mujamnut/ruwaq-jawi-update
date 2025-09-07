import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  final Widget child;
  
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityProvider>(
      builder: (context, connectivity, _) {
        return Column(
          children: [
            // Show banner when offline
            if (connectivity.isOffline)
              Container(
                width: double.infinity,
                color: AppTheme.errorColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tiada sambungan internet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await connectivity.refreshConnectivity();
                          if (!context.mounted) return;
                          
                          if (connectivity.isOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Sambungan internet dipulihkan'),
                                  ],
                                ),
                                backgroundColor: AppTheme.successColor,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Text(
                          'Cuba Lagi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

/// Dialog untuk tunjuk pengguna internet diperlukan
class InternetRequiredDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;
  
  const InternetRequiredDialog({
    super.key,
    this.title = 'Sambungan Internet Diperlukan',
    this.message = 'Ciri ini memerlukan sambungan internet. Sila pastikan peranti anda disambungkan ke internet.',
    this.onRetry,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: AppTheme.errorColor,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppTheme.errorColor,
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
          Text(message),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.errorColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pastikan WiFi atau data selular diaktifkan.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.textLightColor,
          ),
          child: const Text('Cuba Lagi'),
        ),
      ],
    );
  }
}

/// Helper function untuk check internet dan tunjuk dialog jika offline
Future<bool> requiresInternet(BuildContext context, {String? message}) async {
  final connectivity = context.read<ConnectivityProvider>();
  
  if (connectivity.isOffline) {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InternetRequiredDialog(
        message: message ?? 'Ciri ini memerlukan sambungan internet. Sila pastikan peranti anda disambungkan ke internet.',
        onRetry: () async {
          await connectivity.refreshConnectivity();
        },
      ),
    );
    
    // Return current connection status after dialog
    return connectivity.isOnline;
  }
  
  return true;
}
