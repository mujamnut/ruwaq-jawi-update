import 'package:flutter/material.dart';
import '../../../../../core/providers/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../managers/home_data_manager.dart';

class HomeProfileAvatarWidget extends StatelessWidget {
  final AuthProvider authProvider;

  const HomeProfileAvatarWidget({
    super.key,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    final userProfile = authProvider.userProfile;
    final userName = userProfile?.fullName ?? 'User';
    final profileImageUrl = userProfile?.avatarUrl;
    final isPremium = authProvider.hasActiveSubscription;

    final dataManager = HomeDataManager(onStateChanged: () {});
    final initials = dataManager.getInitials(userName);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isPremium
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFFFD700),
                      const Color(0xFFFFA500),
                      const Color(0xFFFFD700),
                      const Color(0xFFDAA520),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  )
                : null,
            border: isPremium ? null : Border.all(color: Colors.white, width: 2),
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
        ),
        // Premium crown icon
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
