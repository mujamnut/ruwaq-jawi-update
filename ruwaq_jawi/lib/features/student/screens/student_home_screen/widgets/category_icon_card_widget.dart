import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class CategoryIconCardWidget extends StatelessWidget {
  final dynamic category;
  final int totalCount;

  const CategoryIconCardWidget({
    super.key,
    required this.category,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/category/${category.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconBadge(),
              const SizedBox(height: 10),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.borderColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$totalCount item',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gradientStart.withValues(alpha: 0.10),
            AppTheme.gradientEnd.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(
          color: AppTheme.gradientStart.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Center(
        child: PhosphorIcon(
          _iconForCategoryName(category.name?.toString() ?? ''),
          color: AppTheme.textPrimaryColor,
          size: 26,
        ),
      ),
    );
  }

  IconData _iconForCategoryName(String name) {
    final n = name.toLowerCase();
    if (n.contains('quran') || n.contains('alquran') || n.contains('al-quran')) {
      return PhosphorIcons.bookOpen();
    }
    if (n.contains('fiqh')) {
      return PhosphorIcons.scales();
    }
    if (n.contains('hadith') || n.contains('hadis')) {
      return PhosphorIcons.quotes();
    }
    if (n.contains('akidah') || n.contains('aqidah') || n.contains('tauhid')) {
      return PhosphorIcons.shieldCheck();
    }
    if (n.contains('sirah') || n.contains('seerah') || n.contains('sejarah')) {
      return PhosphorIcons.compass();
    }
    if (n.contains('akhlak') || n.contains('adab') || n.contains('etik')) {
      return PhosphorIcons.handsPraying();
    }
    if (n.contains('usul') || n.contains('usul fiqh')) {
      return PhosphorIcons.code();
    }
    if (n.contains('bahasa') || n.contains('arab')) {
      return PhosphorIcons.textAa();
    }
    return PhosphorIcons.books();
  }
}

