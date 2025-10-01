import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/models/video_kitab.dart';

class PlayerAppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final VideoKitab? kitab;
  final bool isSaved;
  final bool isSaveLoading;
  final VoidCallback? onToggleSaved;

  const PlayerAppBarWidget({
    super.key,
    this.kitab,
    required this.isSaved,
    required this.isSaveLoading,
    this.onToggleSaved,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        kitab?.title ?? 'Memuat...',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimaryColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: isSaveLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: HugeIcon(
                      key: ValueKey(isSaved),
                      icon: isSaved
                          ? HugeIcons.strokeRoundedFavourite
                          : HugeIcons.strokeRoundedHeartAdd,
                      color: isSaved
                          ? const Color(0xFFE91E63)
                          : AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                  ),
            onPressed: isSaveLoading ? null : onToggleSaved,
            tooltip: isSaved ? 'Buang Video dari Simpan' : 'Simpan Video',
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}