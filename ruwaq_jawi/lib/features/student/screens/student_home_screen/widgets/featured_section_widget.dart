import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/kitab_provider.dart';
import '../../../../../core/providers/connectivity_provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../managers/home_scroll_manager.dart';
import 'featured_card_widget.dart';

class FeaturedSectionWidget extends StatelessWidget {
  final HomeScrollManager scrollManager;
  final AnimationController progressAnimationController;
  final Function(int) onTotalCardsChanged;

  const FeaturedSectionWidget({
    super.key,
    required this.scrollManager,
    required this.progressAnimationController,
    required this.onTotalCardsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<KitabProvider, ConnectivityProvider>(
      builder: (context, kitabProvider, connectivityProvider, child) {
        // Show loading state
        if (kitabProvider.isLoading) {
          return _buildLoadingState();
        }

        // Show error state when offline or has error
        if (connectivityProvider.isOffline || kitabProvider.errorMessage != null) {
          return _buildErrorState(connectivityProvider, kitabProvider);
        }

        // Show only premium video kitab for featured section
        final featuredContent = kitabProvider.premiumVideoKitab.take(5).toList();

        if (featuredContent.isEmpty) {
          return const SizedBox.shrink();
        }

        // Update total cards count for auto-scroll
        onTotalCardsChanged(featuredContent.length);

        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.star(PhosphorIconsStyle.fill),
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Pilihan Utama',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 240,
                ),
                child: PageView.builder(
                  controller: scrollManager.featuredScrollController,
                  padEnds: false,
                  clipBehavior: Clip.none,
                  onPageChanged: scrollManager.onPageChanged,
                  itemBuilder: (context, index) {
                    final actualIndex = index % featuredContent.length;
                    final content = featuredContent[actualIndex];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: FeaturedCardWidget(content: content),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildDotsIndicator(featuredContent.length),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                width: 300,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    ConnectivityProvider connectivityProvider,
    KitabProvider kitabProvider,
  ) {
    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            connectivityProvider.isOffline
                ? Icons.cloud_off_outlined
                : Icons.error_outline,
            color: AppTheme.textSecondaryColor,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            connectivityProvider.isOffline
                ? 'Tiada sambungan internet'
                : kitabProvider.errorMessage ?? 'Tidak dapat memuat kandungan',
            style: TextStyle(
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDotsIndicator(int totalCards) {
    if (totalCards == 0) return const SizedBox.shrink();

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalCards, (index) {
          final isActive = index == (scrollManager.currentCardIndex % totalCards);

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: isActive
                ? AnimatedBuilder(
                    animation: progressAnimationController,
                    builder: (context, child) {
                      return Container(
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: scrollManager.userIsScrolling
                              ? 0
                              : progressAnimationController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.borderColor,
                    ),
                  ),
          );
        }),
      ),
    );
  }
}
