import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

import 'package:ruwaq_jawi/core/providers/auth_provider.dart';
import 'package:ruwaq_jawi/core/theme/app_theme.dart';

import '../managers/admin_dashboard_animation_manager.dart';

class AdminDashboardAppBar extends StatefulWidget implements PreferredSizeWidget {
  const AdminDashboardAppBar({
    super.key,
    required this.animationManager,
    required this.notificationCountFuture,
    required this.onNotificationTap,
    required this.onProfileTap,
  });

  final AdminDashboardAnimationManager animationManager;
  final Future<int> Function() notificationCountFuture;
  final VoidCallback onNotificationTap;
  final VoidCallback onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<AdminDashboardAppBar> createState() => _AdminDashboardAppBarState();
}

class _AdminDashboardAppBarState extends State<AdminDashboardAppBar> {
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('🔵 [APPBAR:initState] START - hashCode: $hashCode');
    }
    _loadNotificationCount();
    if (kDebugMode) {
      debugPrint('🔵 [APPBAR:initState] END');
    }
  }

  Future<void> _loadNotificationCount() async {
    try {
      if (kDebugMode) {
        debugPrint('📬 [APPBAR:_loadNotificationCount] START');
      }
      final count = await widget.notificationCountFuture();
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🟢 [APPBAR:_loadNotificationCount] setState BEFORE - mounted:$mounted, count:$count');
        }
        setState(() {
          _notificationCount = count;
        });
        if (kDebugMode) {
          debugPrint('🟢 [APPBAR:_loadNotificationCount] setState AFTER');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [APPBAR:_loadNotificationCount] SKIP - NOT MOUNTED');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [APPBAR:_loadNotificationCount] ERROR: $e');
      }
      if (mounted) {
        if (kDebugMode) {
          debugPrint('🟢 [APPBAR:_loadNotificationCount] setState(error) BEFORE - mounted:$mounted');
        }
        setState(() {
          _notificationCount = 0;
        });
        if (kDebugMode) {
          debugPrint('🟢 [APPBAR:_loadNotificationCount] setState(error) AFTER');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🏗️ [APPBAR:build] START - count:$_notificationCount');
    }
    return PreferredSize(
      preferredSize: widget.preferredSize,
      child: AnimatedBuilder(
        animation: widget.animationManager.appBarAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, -kToolbarHeight * widget.animationManager.appBarAnimation.value),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00BF6D),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BF6D).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                title: AnimatedBuilder(
                  animation: widget.animationManager.appBarAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 1.0 - widget.animationManager.appBarAnimation.value,
                      child: SlideTransition(
                        position: widget.animationManager.titleSlideAnimation,
                        child: const Text(
                          'Dashboard Admin',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
                foregroundColor: AppTheme.textLightColor,
                elevation: 0,
                actions: [
                  AnimatedBuilder(
                    animation: widget.animationManager.appBarAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: 1.0 - widget.animationManager.appBarAnimation.value,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Stack(
                                children: [
                                  const HugeIcon(
                                    icon: HugeIcons.strokeRoundedNotification03,
                                    color: Colors.white,
                                    size: 24.0,
                                  ),
                                  if (_notificationCount > 0)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 12,
                                          minHeight: 12,
                                        ),
                                        child: Text(
                                          _notificationCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              onPressed: () {
                                widget.onNotificationTap();
                                // Refresh count after opening notifications
                                _loadNotificationCount();
                              },
                              tooltip: 'Notifikasi',
                            ),
                            const SizedBox(width: 8),
                            Consumer<AuthProvider>(
                              builder: (context, authProvider, child) {
                                if (kDebugMode) {
                                  debugPrint('🔶 [APPBAR:Consumer<AuthProvider>] Building avatar - hasProfile:${authProvider.userProfile != null}');
                                }
                                return GestureDetector(
                                  onTap: widget.onProfileTap,
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                                      radius: 18,
                                      child: authProvider.userProfile?.avatarUrl != null
                                          ? ClipOval(
                                              child: Image.network(
                                                authProvider.userProfile!.avatarUrl!,
                                                width: 36,
                                                height: 36,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) =>
                                                    const HugeIcon(
                                                  icon: HugeIcons.strokeRoundedUser,
                                                  color: Colors.white,
                                                  size: 20.0,
                                                ),
                                              ),
                                            )
                                          : const HugeIcon(
                                              icon: HugeIcons.strokeRoundedUser,
                                              color: Colors.white,
                                              size: 20.0,
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
