import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/preview_models.dart';
import '../services/preview_service.dart';
import '../theme/app_theme.dart';

/// Preview badge widget to show preview availability
class PreviewBadge extends StatelessWidget {
  final PreviewContent preview;
  final PreviewBadgeStyle style;
  final VoidCallback? onTap;

  const PreviewBadge({
    super.key,
    required this.preview,
    this.style = PreviewBadgeStyle.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PreviewBadgeStyle.compact:
        return _buildCompactBadge();
      case PreviewBadgeStyle.detailed:
        return _buildDetailedBadge();
      case PreviewBadgeStyle.icon:
        return _buildIconBadge();
    }
  }

  Widget _buildCompactBadge() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getPreviewColor().withValues(alpha: 0.1),
          border: Border.all(color: _getPreviewColor()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getPreviewIcon(),
              size: 12,
              color: _getPreviewColor(),
            ),
            const SizedBox(width: 4),
            Text(
              preview.previewType.displayName.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getPreviewColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedBadge() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _getPreviewColor().withValues(alpha: 0.05),
          border: Border.all(color: _getPreviewColor().withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  _getPreviewIcon(),
                  size: 16,
                  color: _getPreviewColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  preview.previewType.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getPreviewColor(),
                  ),
                ),
              ],
            ),
            if (preview.previewDescription != null) ...[
              const SizedBox(height: 4),
              Text(
                preview.previewDescription!,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (preview.previewDurationSeconds != null ||
                preview.previewPages != null) ...[
              const SizedBox(height: 4),
              Text(
                preview.previewDisplayText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _getPreviewColor(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconBadge() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _getPreviewColor(),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getPreviewIcon(),
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getPreviewColor() {
    switch (preview.previewType) {
      case PreviewType.freeTrial:
        return AppTheme.successColor;
      case PreviewType.teaser:
        return AppTheme.primaryColor;
      case PreviewType.demo:
        return AppTheme.warningColor;
      case PreviewType.sample:
        return AppTheme.infoColor;
    }
  }

  IconData _getPreviewIcon() {
    switch (preview.previewType) {
      case PreviewType.freeTrial:
        return HugeIcons.strokeRoundedGift;
      case PreviewType.teaser:
        return HugeIcons.strokeRoundedPlay;
      case PreviewType.demo:
        return HugeIcons.strokeRoundedPresentation07;
      case PreviewType.sample:
        return HugeIcons.strokeRoundedEye;
    }
  }
}

/// Preview indicator for content that has no preview
class NoPreviewIndicator extends StatelessWidget {
  final PreviewIndicatorStyle style;

  const NoPreviewIndicator({
    super.key,
    this.style = PreviewIndicatorStyle.subtle,
  });

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PreviewIndicatorStyle.subtle:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.textSecondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HugeIcons.strokeRoundedLock,
                size: 12,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(width: 4),
              Text(
                'PREMIUM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        );
      case PreviewIndicatorStyle.prominent:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            border: Border.all(color: AppTheme.primaryColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                HugeIcons.strokeRoundedCrown,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'Premium Only',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// Async preview badge that loads preview data
class AsyncPreviewBadge extends StatelessWidget {
  final PreviewContentType contentType;
  final String contentId;
  final PreviewBadgeStyle style;
  final VoidCallback? onTap;

  const AsyncPreviewBadge({
    super.key,
    required this.contentType,
    required this.contentId,
    this.style = PreviewBadgeStyle.compact,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreviewContent?>(
      future: _loadPreview(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return PreviewBadge(
            preview: snapshot.data!,
            style: style,
            onTap: onTap,
          );
        }

        // No preview available
        return const NoPreviewIndicator();
      },
    );
  }

  Future<PreviewContent?> _loadPreview() async {
    try {
      return await PreviewService.getPrimaryPreview(
        contentType: contentType,
        contentId: contentId,
      );
    } catch (e) {
      print('Error loading preview: $e');
      return null;
    }
  }
}

/// Preview list widget for admin management
class PreviewListTile extends StatelessWidget {
  final PreviewContent preview;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleStatus;

  const PreviewListTile({
    super.key,
    required this.preview,
    this.onEdit,
    this.onDelete,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: preview.isActive
              ? AppTheme.successColor.withValues(alpha: 0.1)
              : AppTheme.textSecondaryColor.withValues(alpha: 0.1),
          child: Icon(
            _getContentTypeIcon(),
            color: preview.isActive
                ? AppTheme.successColor
                : AppTheme.textSecondaryColor,
          ),
        ),
        title: Text(
          preview.contentTitle ?? 'Unknown Content',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${preview.contentType.displayName} • ${preview.previewType.displayName}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            if (preview.previewDescription != null) ...[
              const SizedBox(height: 2),
              Text(
                preview.previewDescription!,
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              preview.previewDisplayText,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: preview.isActive
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.textSecondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                preview.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: preview.isActive
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ),

            // Actions menu
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit?.call();
                    break;
                  case 'toggle':
                    onToggleStatus?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(HugeIcons.strokeRoundedEdit02),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: ListTile(
                    leading: Icon(preview.isActive
                        ? HugeIcons.strokeRoundedEye
                        : HugeIcons.strokeRoundedEye),
                    title: Text(preview.isActive ? 'Deactivate' : 'Activate'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(HugeIcons.strokeRoundedDelete02),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getContentTypeIcon() {
    switch (preview.contentType) {
      case PreviewContentType.videoEpisode:
        return HugeIcons.strokeRoundedPlay;
      case PreviewContentType.ebook:
        return HugeIcons.strokeRoundedBook02;
      case PreviewContentType.videoKitab:
        return HugeIcons.strokeRoundedVideo01;
    }
  }
}

enum PreviewBadgeStyle {
  compact,
  detailed,
  icon,
}

enum PreviewIndicatorStyle {
  subtle,
  prominent,
}