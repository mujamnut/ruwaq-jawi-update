import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../core/models/ebook.dart';
import '../../../../../core/theme/app_theme.dart';

class EbookActionButtonsWidget extends StatelessWidget {
  final Ebook ebook;
  final bool isPremiumLocked;
  final VoidCallback onReadingOptions;
  final double animationValue;

  const EbookActionButtonsWidget({
    super.key,
    required this.ebook,
    required this.isPremiumLocked,
    required this.onReadingOptions,
    this.animationValue = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: animationValue),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremiumLocked
                      ? [
                          AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                          AppTheme.textSecondaryColor.withValues(alpha: 0.4),
                        ]
                      : [
                          AppTheme.primaryColor,
                          AppTheme.primaryColor.withValues(alpha: 0.8),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isPremiumLocked
                        ? Colors.black.withValues(alpha: 0.1)
                        : AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onReadingOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: HugeIcon(
                  icon: isPremiumLocked
                      ? HugeIcons.strokeRoundedCrown
                      : HugeIcons.strokeRoundedBook02,
                  color: Colors.white,
                  size: 22,
                ),
                label: Text(
                  isPremiumLocked ? 'LANGGAN UNTUK BACA' : 'BACA SEKARANG',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}