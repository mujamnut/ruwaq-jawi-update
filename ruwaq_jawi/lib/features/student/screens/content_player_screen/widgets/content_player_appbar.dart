import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/theme/app_theme.dart';

class ContentPlayerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VideoKitab? kitab;
  final bool isSaved;
  final bool isSaveLoading;
  final VoidCallback onToggleSaved;

  const ContentPlayerAppBar({
    super.key,
    required this.kitab,
    required this.isSaved,
    required this.isSaveLoading,
    required this.onToggleSaved,
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
      leading: IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => context.pop(),
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
        IconButton(
          icon: isSaveLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: PhosphorIcon(
                    key: ValueKey(isSaved),
                    isSaved
                        ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                        : PhosphorIcons.heart(),
                    color: isSaved
                        ? const Color(0xFFE91E63)
                        : AppTheme.textSecondaryColor,
                    size: 24,
                  ),
                ),
          onPressed: isSaveLoading ? null : onToggleSaved,
          tooltip: isSaved ? 'Buang Video dari Simpan' : 'Simpan Video',
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}