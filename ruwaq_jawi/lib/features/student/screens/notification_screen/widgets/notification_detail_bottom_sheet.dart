import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../core/models/user_notification.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/notification_ui_utils.dart';

/// Beautiful bottom sheet untuk display full notification details
/// dengan smooth animations dan clear action buttons
class NotificationDetailBottomSheet extends StatefulWidget {
  final UserNotificationItem notification;
  final bool isRead;
  final VoidCallback onMarkAsRead;
  final VoidCallback onMarkAsUnread;
  final VoidCallback onDelete;
  final Function(BuildContext)? onNavigate;

  const NotificationDetailBottomSheet({
    super.key,
    required this.notification,
    required this.isRead,
    required this.onMarkAsRead,
    required this.onMarkAsUnread,
    required this.onDelete,
    this.onNavigate,
  });

  @override
  State<NotificationDetailBottomSheet> createState() =>
      _NotificationDetailBottomSheetState();

  /// Static method untuk show bottom sheet
  static Future<void> show({
    required BuildContext context,
    required UserNotificationItem notification,
    required bool isRead,
    required VoidCallback onMarkAsRead,
    required VoidCallback onMarkAsUnread,
    required VoidCallback onDelete,
    Function(BuildContext)? onNavigate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => NotificationDetailBottomSheet(
        notification: notification,
        isRead: isRead,
        onMarkAsRead: onMarkAsRead,
        onMarkAsUnread: onMarkAsUnread,
        onDelete: onDelete,
        onNavigate: onNavigate,
      ),
    );
  }
}

class _NotificationDetailBottomSheetState
    extends State<NotificationDetailBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.notification.type.toLowerCase();
    final color = notificationColorForType(type);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              _buildDragHandle(),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and type
                      _buildHeader(color, type),
                      const SizedBox(height: 24),

                      // Title
                      _buildTitle(),
                      const SizedBox(height: 16),

                      // Full message body (NO TRUNCATION!)
                      _buildBody(),
                      const SizedBox(height: 24),

                      // Metadata
                      _buildMetadata(),
                      const SizedBox(height: 32),

                      // Action buttons
                      _buildActionButtons(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppTheme.borderColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(Color color, String type) {
    return Row(
      children: [
        // Icon with color
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: PhosphorIcon(
              notificationIconForType(type),
              color: color,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Type badge and status
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  typeDisplayName(type),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Read status
              Row(
                children: [
                  Icon(
                    widget.isRead ? Icons.check_circle : Icons.circle,
                    size: 14,
                    color: widget.isRead
                        ? AppTheme.successColor
                        : AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isRead ? 'Dibaca' : 'Belum dibaca',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Text(
      widget.notification.title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
            height: 1.3,
          ),
    );
  }

  Widget _buildBody() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderColor,
          width: 1,
        ),
      ),
      child: Text(
        widget.notification.body,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              color: AppTheme.textPrimaryColor,
              height: 1.6,
              letterSpacing: 0.2,
            ),
        // NO maxLines - show FULL message!
      ),
    );
  }

  Widget _buildMetadata() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildMetadataRow(
            icon: PhosphorIcons.clock(),
            label: 'Diterima',
            value: _formatDateTime(widget.notification.deliveredAt),
          ),
          if (widget.notification.priority == 'high') ...[
            const SizedBox(height: 12),
            _buildMetadataRow(
              icon: PhosphorIcons.warning(),
              label: 'Keutamaan',
              value: 'Tinggi',
              valueColor: AppTheme.errorColor,
            ),
          ],
          if (widget.notification.actionUrl != null) ...[
            const SizedBox(height: 12),
            _buildMetadataRow(
              icon: PhosphorIcons.link(),
              label: 'Tindakan',
              value: 'Pautan tersedia',
              valueColor: AppTheme.primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        PhosphorIcon(
          icon,
          size: 16,
          color: AppTheme.textSecondaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final hasActionUrl = widget.notification.actionUrl != null &&
        widget.notification.actionUrl!.isNotEmpty &&
        widget.notification.actionUrl != '/home';

    return Column(
      children: [
        // Primary action: Navigate (if has actionUrl)
        if (hasActionUrl)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
                widget.onNavigate?.call(context);
              },
              icon: PhosphorIcon(
                PhosphorIcons.arrowRight(),
                size: 20,
              ),
              label: const Text('Lihat Kandungan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (hasActionUrl) const SizedBox(height: 12),

        // Link utilities row (copy/share)
        if (hasActionUrl)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = widget.notification.actionUrl!;
                    await Clipboard.setData(ClipboardData(text: url));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Pautan disalin'),
                          backgroundColor: AppTheme.successColor,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                  icon: PhosphorIcon(PhosphorIcons.copy(), size: 18),
                  label: const Text('Salin Pautan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final url = widget.notification.actionUrl!;
                    await Share.share(url);
                  },
                  icon: PhosphorIcon(PhosphorIcons.shareNetwork(), size: 18),
                  label: const Text('Kongsi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (hasActionUrl) const SizedBox(height: 12),

        // Secondary actions row
        Row(
          children: [
            // Mark as read/unread
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (widget.isRead) {
                    widget.onMarkAsUnread();
                  } else {
                    widget.onMarkAsRead();
                  }
                  Navigator.of(context).pop();
                },
                icon: PhosphorIcon(
                  widget.isRead ? PhosphorIcons.eye() : PhosphorIcons.check(),
                  size: 18,
                ),
                label: Text(
                  widget.isRead ? 'Belum baca' : 'Tandai baca',
                  style: const TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Delete button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showDeleteConfirmation(context);
                },
                icon: PhosphorIcon(
                  PhosphorIcons.trash(),
                  size: 18,
                ),
                label: const Text(
                  'Padam',
                  style: TextStyle(fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(color: AppTheme.errorColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.trash(),
              color: AppTheme.errorColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text('Padam Notifikasi?'),
          ],
        ),
        content: const Text(
          'Notifikasi ini akan dipadam secara kekal. Tindakan ini tidak boleh dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Padam'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop(); // Close bottom sheet
      widget.onDelete();
    }
  }

  IconData _getNotificationIcon(String type) => notificationIconForType(type);

  Color _getNotificationColor(String type) => notificationColorForType(type);

  String _getTypeDisplayName(String type) => typeDisplayName(type);

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} minggu yang lalu';
    } else {
      // Show full date for older notifications
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
