import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/models/user_notification.dart';
import '../../../../../core/theme/app_theme.dart';

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
    final user = Supabase.instance.client.auth.currentUser;
    final isRead = user != null ? widget.notification.isReadByUser(user.id) : true;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with unread dot
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTitle()),
                          if (!isRead) ...[
                            const SizedBox(width: 12),
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Body
                      _buildBody(),
                      const SizedBox(height: 16),

                      // Time
                      Text(
                        _formatDateTime(widget.notification.deliveredAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
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


  Widget _buildTitle() {
    return Text(
      widget.notification.title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryColor,
            height: 1.3,
          ),
    );
  }

  Widget _buildBody() {
    return Text(
      widget.notification.body,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.textSecondaryColor,
            height: 1.5,
          ),
    );
  }


  Widget _buildActionButtons(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.onMarkAsRead();
          Navigator.of(context).pop();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimaryColor,
          side: BorderSide(color: AppTheme.borderColor),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Done'),
      ),
    );
  }


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
