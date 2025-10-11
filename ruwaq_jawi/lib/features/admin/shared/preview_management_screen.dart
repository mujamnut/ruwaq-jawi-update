import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/models/preview_models.dart';
import '../../../core/services/preview_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/preview_badge.dart';
import 'preview_form_screen.dart';

class AdminPreviewManagementScreen extends StatefulWidget {
  const AdminPreviewManagementScreen({super.key});

  @override
  State<AdminPreviewManagementScreen> createState() =>
      _AdminPreviewManagementScreenState();
}

class _AdminPreviewManagementScreenState
    extends State<AdminPreviewManagementScreen> {
  List<PreviewContent> _previews = [];
  bool _isLoading = true;
  String _errorMessage = '';
  PreviewContentType? _selectedContentType;
  PreviewType? _selectedPreviewType;
  bool? _selectedActiveStatus;

  @override
  void initState() {
    super.initState();
    _loadPreviews();
  }

  Future<void> _loadPreviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final filter = PreviewQueryFilter(
        contentType: _selectedContentType,
        previewType: _selectedPreviewType,
        isActive: _selectedActiveStatus,
      );

      final previews = await PreviewService.getPreviewContent(
        filter: filter,
        includeContentDetails: true,
      );

      setState(() {
        _previews = previews;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load previews: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePreview(PreviewContent preview) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Preview'),
        content: Text(
          'Are you sure you want to delete the preview for "${preview.contentTitle ?? 'Unknown Content'}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PreviewService.deletePreview(preview.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview deleted successfully')),
        );
        _loadPreviews();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete preview: $e')));
      }
    }
  }

  Future<void> _togglePreviewStatus(PreviewContent preview) async {
    try {
      await PreviewService.togglePreviewStatus(preview.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preview.isActive
                ? 'Preview deactivated successfully'
                : 'Preview activated successfully',
          ),
        ),
      );
      _loadPreviews();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to toggle preview status: $e')),
      );
    }
  }

  void _editPreview(PreviewContent preview) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPreviewFormScreen(
          recordId: preview.id,
        ),
      ),
    ).then((_) => _loadPreviews());
  }

  void _addNewPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminPreviewFormScreen(),
      ),
    ).then((_) => _loadPreviews());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Preview Management',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            HugeIcons.strokeRoundedArrowLeft02,
            color: AppTheme.textPrimaryColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              HugeIcons.strokeRoundedAdd01,
              color: AppTheme.primaryColor,
            ),
            onPressed: _addNewPreview,
          ),
          IconButton(
            icon: const Icon(
              HugeIcons.strokeRoundedRefresh,
              color: AppTheme.textSecondaryColor,
            ),
            onPressed: _loadPreviews,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<PreviewContentType>(
                        initialValue: _selectedContentType,
                        decoration: const InputDecoration(
                          labelText: 'Content Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<PreviewContentType>(
                            value: null,
                            child: Text('All Types'),
                          ),
                          ...PreviewContentType.values.map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedContentType = value;
                          });
                          _loadPreviews();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<PreviewType>(
                        initialValue: _selectedPreviewType,
                        decoration: const InputDecoration(
                          labelText: 'Preview Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<PreviewType>(
                            value: null,
                            child: Text('All Previews'),
                          ),
                          ...PreviewType.values.map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPreviewType = value;
                          });
                          _loadPreviews();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<bool>(
                        initialValue: _selectedActiveStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem<bool>(
                            value: null,
                            child: Text('All Status'),
                          ),
                          DropdownMenuItem(value: true, child: Text('Active')),
                          DropdownMenuItem(
                            value: false,
                            child: Text('Inactive'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedActiveStatus = value;
                          });
                          _loadPreviews();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content Section
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          HugeIcons.strokeRoundedAlert02,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPreviews,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _previews.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          HugeIcons.strokeRoundedEye,
                          size: 64,
                          color: AppTheme.textSecondaryColor,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No previews found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create your first preview to get started',
                          style: TextStyle(color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
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
          ),
        ],
      ),
    );
  }
}
