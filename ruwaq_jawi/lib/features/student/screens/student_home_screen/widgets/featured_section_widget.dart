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
          color: Colors.transparent,
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
                  allowImplicitScrolling: true,
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

    return AnimatedBuilder(
      animation: scrollManager.featuredScrollController,
      builder: (context, _) {
        final controller = scrollManager.featuredScrollController;
        final fallbackIndex = scrollManager.currentCardIndex % totalCards;
        final double page = controller.hasClients
            ? (controller.page ?? fallbackIndex.toDouble())
            : fallbackIndex.toDouble();
        final double logical = totalCards == 0
            ? 0.0
            : (page % totalCards);

        double circularDistance(double a, double b, int n) {
          final diff = (a - b).abs();
          return diff <= n / 2 ? diff : n - diff;
        }

        return Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalCards, (index) {
              final dist = circularDistance(index.toDouble(), logical, totalCards);
              final t = (1.0 - dist.clamp(0.0, 1.0)); // 0..1 morph: dot->bar
              final tEased = Curves.easeOut.transform(t);

              // Size morph
              final double width = 8 + (24 - 8) * tEased;
              final double height = 8 - (8 - 4) * tEased;
              final double radius = height / 2;

              // Progress fill: only when settled on this index and not user-scrolling
              final bool isSettledActive =
                  (index == (scrollManager.currentCardIndex % totalCards));
              final bool showProgress = isSettledActive && !scrollManager.userIsScrolling;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: AnimatedBuilder(
                  animation: progressAnimationController,
                  builder: (context, _) {
                    final double fill = showProgress
                        ? progressAnimationController.value
                        : 0.0; // avoid pre-filling during drag for smoothness
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: fill,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
