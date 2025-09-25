import 'package:flutter/material.dart';
import '../models/preview_models.dart';
import '../services/preview_service.dart';
import '../widgets/preview_badge.dart';
import '../theme/app_theme.dart';

/// Example of how to integrate unified preview system with episode lists
class EpisodeListWithPreviews extends StatelessWidget {
  final List<Map<String, dynamic>> episodes;
  final Function(String episodeId)? onEpisodeTap;

  const EpisodeListWithPreviews({
    super.key,
    required this.episodes,
    this.onEpisodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: episodes.length,
      itemBuilder: (context, index) {
        final episode = episodes[index];
        return _buildEpisodeTile(episode);
      },
    );
  }

  Widget _buildEpisodeTile(Map<String, dynamic> episode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Stack(
          children: [
            // Episode thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                episode['thumbnail_url'] ?? '',
                width: 60,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(
                      width: 60,
                      height: 45,
                      color: AppTheme.surfaceColor,
                      child: const Icon(Icons.video_library),
                    ),
              ),
            ),

            // Preview badge overlay (NEW UNIFIED SYSTEM)
            Positioned(
              top: 2,
              right: 2,
              child: AsyncPreviewBadge(
                contentType: PreviewContentType.videoEpisode,
                contentId: episode['id'],
                style: PreviewBadgeStyle.icon,
                onTap: () => _showPreviewInfo(episode),
              ),
            ),
          ],
        ),
        title: Text(
          episode['title'] ?? 'Unknown Title',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Episode ${episode['part_number'] ?? 0}',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),

            // Preview status using NEW unified system
            FutureBuilder<PreviewContent?>(
              future: PreviewService.getPrimaryPreview(
                contentType: PreviewContentType.videoEpisode,
                contentId: episode['id'],
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return PreviewBadge(
                    preview: snapshot.data!,
                    style: PreviewBadgeStyle.compact,
                  );
                } else {
                  return const NoPreviewIndicator(
                    style: PreviewIndicatorStyle.subtle,
                  );
                }
              },
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.play_circle_fill,
            color: AppTheme.primaryColor,
            size: 32,
          ),
          onPressed: () => onEpisodeTap?.call(episode['id']),
        ),
        onTap: () => onEpisodeTap?.call(episode['id']),
      ),
    );
  }

  void _showPreviewInfo(Map<String, dynamic> episode) {
    // Show preview information dialog
    // This would be implemented in the actual app
  }
}

/// Example of content card with unified preview badge
class ContentCardWithPreview extends StatelessWidget {
  final PreviewContentType contentType;
  final Map<String, dynamic> content;
  final VoidCallback? onTap;

  const ContentCardWithPreview({
    super.key,
    required this.contentType,
    required this.content,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Content image with preview badge
            Stack(
              children: [
                Image.network(
                  content['thumbnail_url'] ?? '',
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(
                        height: 120,
                        color: AppTheme.surfaceColor,
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      ),
                ),

                // Preview badge - NEW UNIFIED SYSTEM
                Positioned(
                  top: 8,
                  left: 8,
                  child: AsyncPreviewBadge(
                    contentType: contentType,
                    contentId: content['id'],
                    style: PreviewBadgeStyle.detailed,
                  ),
                ),
              ],
            ),

            // Content info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content['title'] ?? 'Unknown Title',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (content['author'] != null) ...[
                    Text(
                      'By ${content['author']}',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Content type indicator
                  Row(
                    children: [
                      Icon(
                        _getContentTypeIcon(),
                        size: 16,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        contentType.displayName,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getContentTypeIcon() {
    switch (contentType) {
      case PreviewContentType.videoEpisode:
        return Icons.play_circle_outline;
      case PreviewContentType.ebook:
        return Icons.menu_book;
      case PreviewContentType.videoKitab:
        return Icons.video_library;
    }
  }
}

/// Admin screen example for managing previews using auto-generated forms
class PreviewManagementExample extends StatefulWidget {
  const PreviewManagementExample({super.key});

  @override
  State<PreviewManagementExample> createState() =>
      _PreviewManagementExampleState();
}

class _PreviewManagementExampleState extends State<PreviewManagementExample> {
  List<PreviewContent> _previews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreviews();
  }

  Future<void> _loadPreviews() async {
    try {
      final previews = await PreviewService.getPreviewContent(
        includeContentDetails: true,
      );

      setState(() {
        _previews = previews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewPreview,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _previews.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.preview, size: 64),
                      SizedBox(height: 16),
                      Text('No previews found'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _previews.length,
                  itemBuilder: (context, index) {
                    final preview = _previews[index];
                    return PreviewListTile(
                      preview: preview,
                      onEdit: () => _editPreview(preview),
                      onDelete: () => _deletePreview(preview),
                      onToggleStatus: () => _togglePreviewStatus(preview),
                    );
                  },
                ),
    );
  }

  void _addNewPreview() {
    // Navigate to auto-generated form for preview_content table
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const GenericAdminFormScreen(
          tableName: 'preview_content',
          title: 'Add New Preview',
          fieldConfigs: {
            'content_type': FormFieldConfig(
              label: 'Content Type',
              // Auto-generated dropdown from enum
            ),
            'content_id': FormFieldConfig(
              label: 'Content',
              // This would need custom widget for content selection
            ),
            'preview_type': FormFieldConfig(
              label: 'Preview Type',
              // Auto-generated dropdown from enum
            ),
            'preview_duration_seconds': FormFieldConfig(
              label: 'Preview Duration (seconds)',
              placeholder: 'For video content only',
            ),
            'preview_pages': FormFieldConfig(
              label: 'Preview Pages',
              placeholder: 'For ebook content only',
            ),
          },
          hiddenFields: ['id', 'created_at', 'updated_at'],
        ),
      ),
    ).then((_) => _loadPreviews());
  }

  void _editPreview(PreviewContent preview) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenericAdminFormScreen(
          tableName: 'preview_content',
          recordId: preview.id,
          title: 'Edit Preview',
        ),
      ),
    ).then((_) => _loadPreviews());
  }

  void _deletePreview(PreviewContent preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preview'),
        content: const Text('Are you sure you want to delete this preview?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PreviewService.deletePreview(preview.id);
      _loadPreviews();
    }
  }

  void _togglePreviewStatus(PreviewContent preview) async {
    await PreviewService.togglePreviewStatus(preview.id);
    _loadPreviews();
  }
}

// Placeholder for GenericAdminFormScreen import
// This would normally be imported from the actual file
class GenericAdminFormScreen extends StatelessWidget {
  final String tableName;
  final String? recordId;
  final String? title;
  final Map<String, FormFieldConfig>? fieldConfigs;
  final List<String>? hiddenFields;

  const GenericAdminFormScreen({
    super.key,
    required this.tableName,
    this.recordId,
    this.title,
    this.fieldConfigs,
    this.hiddenFields,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Form')),
      body: const Center(
        child: Text('Auto-generated form would be here'),
      ),
    );
  }
}

// Placeholder for FormFieldConfig
class FormFieldConfig {
  final String? label;
  final String? placeholder;

  const FormFieldConfig({this.label, this.placeholder});
}