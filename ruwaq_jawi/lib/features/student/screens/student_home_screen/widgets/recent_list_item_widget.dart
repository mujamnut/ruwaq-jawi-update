import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_theme.dart';
import '../utils/home_helpers.dart';
import '../../../../../core/providers/saved_items_provider.dart';

class RecentListItemWidget extends StatelessWidget {
  final dynamic content;

  const RecentListItemWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final bool isEbook = content.runtimeType.toString().contains('Ebook');
    final String route = isEbook ? '/ebook/${content.id}' : '/kitab/${content.id}';
    const double thumbSize = 96;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(route),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 112),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(isEbook, thumbSize),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: thumbSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            content.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textPrimaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            content.author ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          PhosphorIcon(
                            isEbook ? PhosphorIcons.filePdf() : PhosphorIcons.videoCamera(),
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isEbook
                                  ? (content.totalPages != null
                                      ? '${content.totalPages} halaman'
                                      : 'E-book')
                                  : (content.totalVideos != null && content.totalVideos > 0
                                      ? '${content.totalVideos} episod'
                                      : 'Video'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showOptionsBottomSheet(context, route),
                icon: PhosphorIcon(
                  PhosphorIcons.dotsThreeVertical(),
                  color: AppTheme.textSecondaryColor,
                  size: 24,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                splashRadius: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(bool isEbook, double size) {
    if (isEbook) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.12),
              AppTheme.primaryColor.withValues(alpha: 0.06),
            ],
          ),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Center(
          child: PhosphorIcon(
            PhosphorIcons.filePdf(PhosphorIconsStyle.fill),
            color: AppTheme.primaryColor,
            size: 34,
          ),
        ),
      );
    }

    // Video thumbnail
    String thumbnailUrl = '';
    if (content.thumbnailUrl != null && content.thumbnailUrl.isNotEmpty) {
      thumbnailUrl = content.thumbnailUrl;
    } else if (content.runtimeType.toString().contains('VideoEpisode') &&
        content.youtubeWatchUrl != null) {
      thumbnailUrl = HomeHelpers.getYouTubeThumbnailUrl(content.youtubeWatchUrl);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        child: thumbnailUrl.isEmpty
            ? Center(
                child: PhosphorIcon(
                  PhosphorIcons.videoCamera(),
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              )
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: PhosphorIcon(
                    PhosphorIcons.videoCamera(),
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      strokeWidth: 2,
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context, String route) {
    final isEbook = content.runtimeType.toString().contains('Ebook');
    final savedProvider = context.read<SavedItemsProvider>();
    final bool isSaved = isEbook
        ? savedProvider.isEbookSaved(content.id)
        : savedProvider.isKitabSaved(content.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: PhosphorIcon(
                    PhosphorIcons.eye(),
                    color: AppTheme.textSecondaryColor,
                  ),
                  title: const Text('Buka'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push(route);
                  },
                ),
                ListTile(
                  leading: PhosphorIcon(
                    isSaved
                        ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                        : PhosphorIcons.heart(),
                    color: isSaved ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                  ),
                  title: Text(isSaved ? 'Buang dari Simpanan' : 'Simpan ke Koleksi'),
                  subtitle: Text(
                    isSaved ? 'Alih keluar dari senarai simpanan' : 'Simpan untuk rujukan kemudian',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    if (isEbook) {
                      await savedProvider.toggleEbookSaved(content);
                    } else {
                      await savedProvider.toggleKitabSaved(content);
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
