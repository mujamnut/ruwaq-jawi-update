import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../managers/home_data_manager.dart';

class HomeProfileAvatarWidget extends StatefulWidget {
  final AuthProvider authProvider;

  const HomeProfileAvatarWidget({
    super.key,
    required this.authProvider,
  });

  @override
  State<HomeProfileAvatarWidget> createState() => _HomeProfileAvatarWidgetState();
}

class _HomeProfileAvatarWidgetState extends State<HomeProfileAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _updateAnimationState();
  }

  void _updateAnimationState() {
    final isPremium = widget.authProvider.hasActiveSubscription;
    if (isPremium) {
      _ringController.repeat();
    } else {
      _ringController.stop();
    }
  }

  @override
  void didUpdateWidget(covariant HomeProfileAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authProvider.hasActiveSubscription !=
        widget.authProvider.hasActiveSubscription) {
      _updateAnimationState();
    }
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = widget.authProvider;
    final userProfile = authProvider.userProfile;
    final userName = userProfile?.fullName ?? 'User';
    final profileImageUrl = userProfile?.avatarUrl;
    final isPremium = authProvider.hasActiveSubscription;

    // Ensure animation reflects current premium state even if provider updates in place
    if (isPremium) {
      if (!_ringController.isAnimating) _ringController.repeat();
    } else {
      if (_ringController.isAnimating) _ringController.stop();
    }

    final dataManager = HomeDataManager(onStateChanged: () {});
    final initials = dataManager.getInitials(userName);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _ringController,
          builder: (context, _) {
            final angle = _ringController.value * 2 * math.pi;
            return AnimatedContainer(
              duration: isPremium
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isPremium
                    ? SweepGradient(
                        colors: const [
                          Color(0xFFFFD700),
                          Color(0xFFFFA500),
                          Color(0xFFFFD700),
                          Color(0xFFDAA520),
                          Color(0xFFFFD700),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        transform: GradientRotation(angle),
                      )
                    : null,
                border:
                    isPremium ? null : Border.all(color: Colors.white, width: 2),
              ),
              padding: EdgeInsets.all(isPremium ? 2 : 1),
              child: isPremium
                  ? Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: ClipOval(
                          child: _buildAvatarContent(
                            profileImageUrl,
                            userName,
                            isPremium,
                            initials,
                            dataManager,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: ClipOval(
                        child: _buildAvatarContent(
                          profileImageUrl,
                          userName,
                          isPremium,
                          initials,
                          dataManager,
                        ),
                      ),
                    ),
            );
          },
        ),
        if (isPremium)
          Positioned(
            right: -1,
            top: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFD700),
                    Color(0xFFB8860B),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
              ),
              child: const Icon(Icons.diamond, size: 9, color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarContent(
    String? profileImageUrl,
    String userName,
    bool isPremium,
    String initials,
    HomeDataManager dataManager,
  ) {
    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return Image.network(
        profileImageUrl,
        width: isPremium ? 32 : 38,
        height: isPremium ? 32 : 38,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(initials, isPremium, dataManager);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: isPremium ? 32 : 38,
            height: isPremium ? 32 : 38,
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return _buildInitialsAvatar(initials, isPremium, dataManager);
    }
  }

  Widget _buildInitialsAvatar(
    String initials,
    bool isPremium,
    HomeDataManager dataManager,
  ) {
    return Container(
      width: isPremium ? 32 : 38,
      height: isPremium ? 32 : 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isPremium
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dataManager.getGradientFromLetter(
                  initials.isNotEmpty ? initials[0] : 'A',
                ),
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: isPremium ? 13 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
