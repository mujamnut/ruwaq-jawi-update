import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/models/preview_models.dart';
import '../../../core/services/preview_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminPreviewFormScreen extends StatefulWidget {
  final String? recordId;

  const AdminPreviewFormScreen({
    super.key,
    this.recordId,
  });

  @override
  State<AdminPreviewFormScreen> createState() => _AdminPreviewFormScreenState();
}

class _AdminPreviewFormScreenState extends State<AdminPreviewFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Form fields
  PreviewContentType? _contentType;
  String? _contentId;
  PreviewType? _previewType;
  int? _previewDurationSeconds;
  int? _previewPages;
  String? _previewDescription;
  int _sortOrder = 0;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    if (widget.recordId != null) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    try {
      final previews = await PreviewService.getPreviewContent(
        includeContentDetails: true,
      );
      final preview = previews.firstWhere((p) => p.id == widget.recordId);

      setState(() {
        _contentType = preview.contentType;
        _contentId = preview.contentId;
        _previewType = preview.previewType;
        _previewDurationSeconds = preview.previewDurationSeconds;
        _previewPages = preview.previewPages;
        _previewDescription = preview.previewDescription;
        _sortOrder = preview.sortOrder;
        _isActive = preview.isActive;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load preview: $e')),
        );
      }
    }
  }

  Future<void> _savePreview() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    // Validate required fields
    if (_contentType == null || _contentId == null || _previewType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final config = PreviewConfig(
        contentType: _contentType!,
        contentId: _contentId!,
        previewType: _previewType!,
        previewDurationSeconds: _previewDurationSeconds,
        previewPages: _previewPages,
        previewDescription: _previewDescription,
        isActive: _isActive,
      );

      final result = widget.recordId != null
          ? await PreviewService.updatePreview(
              previewId: widget.recordId!,
              config: config,
            )
          : await PreviewService.createPreview(config);

      if (mounted) {
        if (result.success) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.message ?? 'Preview saved successfully')),
          );
        } else {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to save preview')),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preview: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.recordId == null ? 'Add Preview Content' : 'Edit Preview Content',
          style: const TextStyle(
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
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _savePreview,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(HugeIcons.strokeRoundedTick02),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Content Type
                    DropdownButtonFormField<PreviewContentType>(
                      initialValue: _contentType,
                      decoration: const InputDecoration(
                        labelText: 'Content Type *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: PreviewContentType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      validator: (value) =>
                          value == null ? 'Please select content type' : null,
                      onChanged: (value) {
                        setState(() {
                          _contentType = value;
                          _contentId = null; // Reset content selection
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Content ID (simplified - in real app, this would be a searchable dropdown)
                    TextFormField(
                      initialValue: _contentId,
                      decoration: const InputDecoration(
                        labelText: 'Content ID *',
                        hintText: 'Enter content UUID',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Please enter content ID' : null,
                      onSaved: (value) => _contentId = value,
                    ),
                    const SizedBox(height: 16),

                    // Preview Type
                    DropdownButtonFormField<PreviewType>(
                      initialValue: _previewType,
                      decoration: const InputDecoration(
                        labelText: 'Preview Type *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: PreviewType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName),
                        );
                      }).toList(),
                      validator: (value) =>
                          value == null ? 'Please select preview type' : null,
                      onChanged: (value) => setState(() => _previewType = value),
                    ),
                    const SizedBox(height: 16),

                    // Conditional fields based on content type
                    if (_contentType == PreviewContentType.videoEpisode ||
                        _contentType == PreviewContentType.videoKitab) ...[
                      TextFormField(
                        initialValue: _previewDurationSeconds?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Preview Duration (seconds)',
                          hintText: '60',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onSaved: (value) =>
                            _previewDurationSeconds = int.tryParse(value ?? ''),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_contentType == PreviewContentType.ebook) ...[
                      TextFormField(
                        initialValue: _previewPages?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Preview Pages',
                          hintText: '5',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: TextInputType.number,
                        onSaved: (value) =>
                            _previewPages = int.tryParse(value ?? ''),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Preview Description
                    TextFormField(
                      initialValue: _previewDescription,
                      decoration: const InputDecoration(
                        labelText: 'Preview Description',
                        hintText: 'Optional description of what this preview shows',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      maxLines: 3,
                      onSaved: (value) => _previewDescription = value,
                    ),
                    const SizedBox(height: 16),

                    // Sort Order
                    TextFormField(
                      initialValue: _sortOrder.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Sort Order',
                        hintText: '0',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (value) =>
                          _sortOrder = int.tryParse(value ?? '0') ?? 0,
                    ),
                    const SizedBox(height: 16),

                    // Active Status
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: SwitchListTile(
                        title: const Text('Active Preview'),
                        subtitle: const Text('Enable/disable this preview'),
                        value: _isActive,
                        activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                        activeThumbColor: AppTheme.primaryColor,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
