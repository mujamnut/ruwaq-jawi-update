import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/providers/notifications_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import 'home_profile_avatar_widget.dart';

class HomeHeaderWidget extends StatelessWidget {
  const HomeHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userName = authProvider.userProfile?.fullName ?? 'Pengguna';
        final firstName = userName.split(' ').first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name highlighted (keep simple, remove salam text)
                      Text(
                        firstName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Typing tagline (type + delete loop)
                      _TypingTagline(
                        messages: const [
                          'Hai, selamat datang kembali!',
                          'Rindu nak tengok kamu baca kitab lagi...',
                          'Nak sambung bacaan semalam ke?',
                          'Biar perlahan, asalkan berterusan.',
                          'Jangan risau, ilmu sentiasa menunggu kamu...',
                          'Selamat membaca, penuntut ilmu sejati.',
                        ],
                      ),
                      const SizedBox(height: 10),
                      // (Removed quick action chips to reduce clutter)
                      const SizedBox.shrink(),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Notification Icon
                    Consumer<NotificationsProvider>(
                      builder: (context, notif, _) {
                        final unread = notif.unreadCount;
                        final icon = IconButton(
                          icon: PhosphorIcon(
                            PhosphorIcons.bell(),
                            color: AppTheme.textPrimaryColor,
                          ),
                          onPressed: () {
                            context.push('/notifications');
                          },
                        );
                        if (unread > 0) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              icon,
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.12,
                                        ),
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        height: 1.0,
                                        letterSpacing: -0.1,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return icon;
                      },
                    ),
                    const SizedBox(width: 12),
                    // Profile Avatar
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: HomeProfileAvatarWidget(
                        authProvider: authProvider,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  splashColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                  highlightColor: AppTheme.primaryColor.withValues(alpha: 0.04),
                  onTap: () => context.push('/search'),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.magnifyingGlass(),
                            color: AppTheme.textSecondaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Cari kitab, video, atau topik...',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontSize: 15,
                                  ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.borderColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PhosphorIcon(
                                  PhosphorIcons.magnifyingGlass(),
                                  color: AppTheme.textSecondaryColor,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Cari',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textSecondaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RotatingTagline extends StatefulWidget {
  final List<String> messages;
  const _RotatingTagline({required this.messages});

  @override
  State<_RotatingTagline> createState() => _RotatingTaglineState();
}

class _RotatingTaglineState extends State<_RotatingTagline> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.messages.isEmpty) return;
      setState(() => _index = (_index + 1) % widget.messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Text(
        widget.messages[_index],
        key: ValueKey(_index),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// Typing + deleting effect tagline
class _TypingTagline extends StatefulWidget {
  final List<String> messages;
  final Duration typeDelay;
  final Duration deleteDelay;
  final Duration holdDelay;
  const _TypingTagline({
    required this.messages,
    this.typeDelay = const Duration(milliseconds: 60),
    this.deleteDelay = const Duration(milliseconds: 40),
    this.holdDelay = const Duration(milliseconds: 900),
  });

  @override
  State<_TypingTagline> createState() => _TypingTaglineState();
}

class _TypingTaglineState extends State<_TypingTagline> {
  int _msg = 0;
  int _chars = 0;
  bool _deleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext(widget.typeDelay);
  }

  void _scheduleNext(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _tick);
  }

  void _tick() {
    if (!mounted || widget.messages.isEmpty) return;
    final text = widget.messages[_msg];
    setState(() {
      if (!_deleting) {
        if (_chars < text.length) {
          _chars++;
          _scheduleNext(widget.typeDelay);
        } else {
          _deleting = true;
          _scheduleNext(widget.holdDelay);
        }
      } else {
        if (_chars > 0) {
          _chars--;
          _scheduleNext(widget.deleteDelay);
        } else {
          _deleting = false;
          _msg = (_msg + 1) % widget.messages.length;
          _scheduleNext(widget.typeDelay);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.messages.isEmpty
        ? ''
        : widget.messages[_msg].substring(0, _chars);
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppTheme.textSecondaryColor,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _QuickChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(icon, size: 16, color: AppTheme.textSecondaryColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
