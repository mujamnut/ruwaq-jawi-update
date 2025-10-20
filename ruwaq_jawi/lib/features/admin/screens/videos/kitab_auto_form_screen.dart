import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'dart:io';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/connectivity_provider.dart';
// import '../../../../core/services/network_service.dart';
import '../../widgets/admin_app_bar.dart';
import '../../widgets/youtube_sync_loading_dialog.dart';

import '../../widgets/youtube_preview_sheet.dart';

class AdminYouTubeAutoFormScreen extends StatefulWidget {
  const AdminYouTubeAutoFormScreen({super.key});

  @override
  State<AdminYouTubeAutoFormScreen> createState() =>
      _AdminYouTubeAutoFormScreenState();
}

class _AdminYouTubeAutoFormScreenState
    extends State<AdminYouTubeAutoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playlistUrlController = TextEditingController();
  final _authorController = TextEditingController();

  String? _selectedCategoryId;
  bool _isPremium = true;
  bool _isActive = true;
  PlatformFile? _selectedPdfFile;

  bool _isLoading = false;
  bool _isLoadingCategories = false;
  List<Map<String, dynamic>> _categories = [];

  bool get _isPlaylistUrlValid =>
      _playlistUrlController.text.contains('playlist?list=');
  bool get _canSync => !_isLoading && !_isLoadingCategories &&
      _isPlaylistUrlValid && (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
    _loadCategories();
  }

  Future<void> _checkAdminAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
      });

      final response = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
        _isLoadingCategories = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _playlistUrlController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AdminAppBar(
        title: 'Auto Mode - Add Playlist',
        icon: PhosphorIcons.lightning(PhosphorIconsStyle.fill),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Setup Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.lightning(PhosphorIconsStyle.fill),
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Setup Mode',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'System will auto-fetch playlist details and create episodes',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.amber.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Playlist URL Section
              _buildSectionHeader(
                context,
                icon: PhosphorIcons.link(),
                title: 'YouTube Playlist URL',
                subtitle: 'Paste the YouTube playlist link',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _playlistUrlController,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/playlist?list=...',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PhosphorIcon(
                      PhosphorIcons.youtubeLogo(),
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Paste',
                        icon: const Icon(Icons.paste_rounded, size: 18),
                        onPressed: () async {
                          final data = await Clipboard.getData('text/plain');
                          final text = data?.text?.trim();
                          if (text != null && text.isNotEmpty) {
                            setState(() {
                              _playlistUrlController.text = text;
                            });
                          }
                        },
                      ),
                      IconButton(
                        tooltip: 'Validate URL',
                        icon: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: _isPlaylistUrlValid
                              ? AppTheme.primaryColor
                              : AppTheme.textSecondaryColor,
                        ),
                        onPressed: () {
                          final valid = _isPlaylistUrlValid;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                valid
                                    ? 'Playlist URL is valid'
                                    : 'URL tidak sah. Pastikan mengandungi "playlist?list="',
                              ),
                              backgroundColor:
                                  valid ? Colors.green : Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a YouTube playlist URL';
                  }
                  if (!value.contains('playlist?list=')) {
                    return 'Please enter a valid YouTube playlist URL';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Auto-validate and show preview button if URL is valid
                  setState(() {});
                },
              ),

              const SizedBox(height: 24),

              // Category Selection
              _buildSectionHeader(
                context,
                icon: PhosphorIcons.tag(),
                title: 'Category',
                subtitle: 'Select the content category',
              ),
              const SizedBox(height: 12),
              _isLoadingCategories
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Loading categories...',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppTheme.textSecondaryColor),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primaryColor),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: PhosphorIcon(
                            PhosphorIcons.tag(),
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      hint: const Text('Select a category'),
                      items: _categories.map((category) {
                        return DropdownMenuItem<String>(
                          value: category['id'].toString(),
                          child: Text(category['name']?.toString() ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),

              const SizedBox(height: 24),

              // Author/Penceramah Section
              _buildSectionHeader(
                context,
                icon: PhosphorIcons.user(),
                title: 'Author / Penceramah',
                subtitle: 'Edit or confirm the author name',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _authorController,
                decoration: InputDecoration(
                  hintText: 'Will auto-fill from YouTube channel name',
                  labelText: 'Nama Penceramah',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PhosphorIcon(
                      PhosphorIcons.user(),
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppTheme.primaryColor),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  helperText: 'Leave empty to use channel name from YouTube',
                ),
                maxLines: 1,
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Settings Section
              _buildSectionHeader(
                context,
                icon: PhosphorIcons.gear(),
                title: 'Settings',
                subtitle: 'Configure playlist settings',
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Column(
                  children: [
                    // Premium Toggle
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.crown(PhosphorIconsStyle.fill),
                            color: Colors.amber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium Content',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                              ),
                              Text(
                                'Requires subscription to access',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isPremium,
                          onChanged: (value) {
                            setState(() {
                              _isPremium = value;
                            });
                          },
                          activeColor: Colors.amber,
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Active Status Toggle
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                            color: Colors.green,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Status',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                              ),
                              Text(
                                'Make playlist visible to students',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PDF Upload Section
              _buildSectionHeader(
                context,
                icon: PhosphorIcons.filePdf(),
                title: 'PDF Upload (Optional)',
                subtitle: 'Add supporting PDF document',
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: _pickPdfFile,
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPdfFile != null
                          ? Colors.green.withValues(alpha: 0.6)
                          : AppTheme.borderColor,
                      width: 1,
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 140),
                  duration: const Duration(milliseconds: 180),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Semantics(
                            label: _selectedPdfFile != null
                                ? 'PDF dipilih'
                                : 'Muat naik PDF',
                            child: PhosphorIcon(
                              _selectedPdfFile != null
                                  ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                                  : PhosphorIcons.cloudArrowUp(),
                              size: 32,
                              color: _selectedPdfFile != null
                                  ? Colors.green
                                  : AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedPdfFile != null
                                ? _selectedPdfFile!.name
                                : 'Tap to upload PDF file',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _selectedPdfFile != null
                                  ? Colors.green
                                  : AppTheme.textPrimaryColor,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedPdfFile != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Size: ${(_selectedPdfFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondaryColor),
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            Text(
                              'PDF files only • Max 50MB',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ],
                      ),
                      if (_selectedPdfFile != null)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  await _previewPdfFile();
                                },
                                icon: Icon(
                                  PhosphorIcons.eye(),
                                  size: 14,
                                ),
                                label: const Text(
                                  'Pratonton',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedPdfFile = null;
                                  });
                                },
                                icon: Icon(
                                  PhosphorIcons.x(),
                                  size: 14,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Buang',
                                  style: TextStyle(fontSize: 12, color: Colors.red),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: PhosphorIcon(
                        PhosphorIcons.x(),
                        size: 18,
                        color: AppTheme.textSecondaryColor,
                      ),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppTheme.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _canSync ? _syncPlaylist : null,
                      icon: _isLoading
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : PhosphorIcon(
                              PhosphorIcons.downloadSimple(),
                              size: 18,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Syncing...'
                            : _canSync
                                ? 'Sync Playlist'
                                : 'Complete required fields',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required PhosphorIconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        PhosphorIcon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check file size (50MB limit)
        if (file.size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('File size must be less than 50MB'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedPdfFile = file;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _previewPdfFile() async {
    if (_selectedPdfFile == null) return;

    try {
      Future<pdfx.PdfDocument>? documentFuture;
      if (_selectedPdfFile!.path != null) {
        final file = File(_selectedPdfFile!.path!);
        if (await file.exists()) {
          documentFuture = pdfx.PdfDocument.openFile(file.path);
        }
      } else if (_selectedPdfFile!.bytes != null) {
        documentFuture = pdfx.PdfDocument.openData(_selectedPdfFile!.bytes!);
      }

      if (documentFuture == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat memuatkan PDF untuk pratonton.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final controller = pdfx.PdfController(document: documentFuture);

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
                    ),
                    child: Row(
                      children: [
                        const Text('Pratonton PDF', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: pdfx.PdfView(
                      controller: controller,
                      builders: pdfx.PdfViewBuilders<pdfx.DefaultBuilderOptions>(
                        options: const pdfx.DefaultBuilderOptions(),
                        documentLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
                        pageLoaderBuilder: (_) => const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, error) => Center(
                          child: Text('Ralat memuatkan PDF: $error'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      controller.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat membuka PDF: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _checkNetworkConnectivity() async {
    try {
      // Use centralized connectivity provider
      final connectivity = context.read<ConnectivityProvider>();
      await connectivity.refreshConnectivity();

      if (connectivity.isOffline) {
        return false;
      }

      // Additional DNS check to verify actual internet access
      final result = await InternetAddress.lookup('supabase.co');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      print('Network connectivity check failed: $e');
      return false;
    }
  }

  Future<void> _syncPlaylist() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('=== AUTO SYNC DEBUG START ===');
      print('Playlist URL: ${_playlistUrlController.text}');
      print('Category ID: $_selectedCategoryId');
      print('Is Premium: $_isPremium');
      print('Is Active: $_isActive');

      // Check network connectivity first
      print('Checking network connectivity...');
      final hasConnectivity = await _checkNetworkConnectivity();
      if (!hasConnectivity) {
        print('No network connectivity detected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No internet connection. Please check your network and try again.',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      print('Network connectivity confirmed');

      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => YouTubeSyncLoadingDialog(
            playlistUrl: _playlistUrlController.text,
          ),
        );
      }

      // Prepare author name (use channel name if not provided)
      final authorName = _authorController.text.trim().isEmpty
          ? null
          : _authorController.text.trim();

      print('Calling edge function: youtube-playlist-sync');
      print(
        'Request body: ${{'playlist_url': _playlistUrlController.text, 'category_id': _selectedCategoryId, 'is_premium': _isPremium, 'is_active': _isActive, 'author': authorName}}',
      );

      // Call YouTube sync API
      final response = await Supabase.instance.client.functions.invoke(
        'youtube-playlist-sync',
        body: {
          'playlist_url': _playlistUrlController.text,
          'category_id': _selectedCategoryId,
          'is_premium': _isPremium,
          'is_active': _isActive,
          if (authorName != null) 'author': authorName,
        },
      );

      print('Edge function response status: ${response.status}');
      print('Edge function response data: ${response.data}');

      if (response.status != 200) {
        print('ERROR: Non-200 status code received');
        print('Error details: ${response.data}');
        throw Exception('Failed to sync playlist: ${response.data}');
      }

      final syncData = response.data;
      print('SUCCESS: Edge function returned data');
      print('Sync data keys: ${syncData?.keys?.toList()}');
      print('Episodes count: ${(syncData?['episodes'] as List?)?.length ?? 0}');

      // Upload PDF if selected
      if (_selectedPdfFile != null && syncData['video_kitab_id'] != null) {
        try {
          print('=== UPLOADING PDF ===');
          print('Video Kitab ID: ${syncData['video_kitab_id']}');
          print('PDF File: ${_selectedPdfFile!.name}');
          print('PDF Size: ${_selectedPdfFile!.size} bytes');

          // Create storage path
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final pdfPath =
              'pdfs/video_kitab_${timestamp}_${_selectedPdfFile!.name}';

          print('Uploading to storage path: $pdfPath');

          // Upload PDF to storage
          await Supabase.instance.client.storage
              .from('video-kitab-files')
              .uploadBinary(pdfPath, _selectedPdfFile!.bytes!);

          print('PDF uploaded to storage successfully');

          // Get public URL
          final pdfUrl = Supabase.instance.client.storage
              .from('video-kitab-files')
              .getPublicUrl(pdfPath);

          print('PDF public URL: $pdfUrl');

          // Update video_kitab with PDF info
          await Supabase.instance.client
              .from('video_kitab')
              .update({
                'pdf_url': pdfUrl,
                'pdf_storage_path': pdfPath,
                'pdf_file_size': _selectedPdfFile!.size,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', syncData['video_kitab_id']);

          print('Video kitab updated with PDF info');
          print('=== PDF UPLOAD SUCCESS ===');

          // Store PDF success flag in syncData for later use
          syncData['pdf_uploaded'] = true;
          syncData['pdf_url'] = pdfUrl;
        } catch (e, stackTrace) {
          print('=== PDF UPLOAD ERROR ===');
          print('Error: ${e.toString()}');
          print('Stack trace: $stackTrace');
          print('=== PDF UPLOAD ERROR END ===');

          // Store PDF failure flag but don't fail entire sync
          syncData['pdf_uploaded'] = false;
          syncData['pdf_error'] = e.toString();

          // Show warning but continue
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Warning: PDF upload failed. You can add it later via Edit.',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } else if (_selectedPdfFile != null) {
        print('WARNING: PDF selected but video_kitab_id not found in response');
      }

      final List<VideoEpisodePreview> episodes =
          (syncData['episodes'] as List?)
              ?.map(
                (episode) => VideoEpisodePreview(
                  title: episode['title'] ?? 'Untitled Episode',
                  duration: episode['duration'],
                  isPreview:
                      false, // Preview status now managed via preview_content table
                ),
              )
              .toList() ??
          [];

      print('Parsed episodes: ${episodes.length}');
      print('=== AUTO SYNC DEBUG SUCCESS ===');

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

                  // Show preview sheet on phones, dialog on wide screens
          final isWide = MediaQuery.of(context).size.width >= 900;
          if (!isWide) {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => YouTubePreviewSheet(
                playlistTitle: syncData['playlist_title'] ?? 'Unknown Playlist',
                playlistDescription: syncData['playlist_description'],
                channelTitle: syncData['channel_title'],
                totalVideos: syncData['total_videos'] ?? 0,
                totalDurationMinutes: syncData['total_duration_minutes'] ?? 0,
                isPremium: _isPremium,
                isActive: _isActive,
                categoryName: _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId)['name']!,
                episodes: episodes,
                pdfUploaded: (syncData['pdf_uploaded'] == true),
                pdfSelected: (_selectedPdfFile != null),
                pdfUrl: syncData['pdf_url'],
                pdfSizeBytes: _selectedPdfFile?.size,
                onApprove: () async {
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'youtube-admin-tools?action=approve_playlist',
                      body: {'playlist_id': syncData['playlist_id']},
                    );
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      String successMessage = '? Playlist approved and published successfully!';
                      if (syncData['pdf_uploaded'] == true) {
                        successMessage = '? Playlist approved and published successfully (with PDF)!';
                      } else if (_selectedPdfFile != null && syncData['pdf_uploaded'] == false) {
                        successMessage = '? Playlist approved! (PDF upload failed - you can add it later)';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(successMessage), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error approving playlist: ${e.toString()}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
                onReject: () async {
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'youtube-admin-tools?action=delete-kitab',
                      body: {'kitab_id': syncData['playlist_id']},
                    );
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Playlist rejected and removed'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error rejecting playlist: ${e.toString()}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
              ),
            );
          } else {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => YouTubePreviewSheet(
                playlistTitle: syncData['playlist_title'] ?? 'Unknown Playlist',
                playlistDescription: syncData['playlist_description'],
                channelTitle: syncData['channel_title'],
                totalVideos: syncData['total_videos'] ?? 0,
                totalDurationMinutes: syncData['total_duration_minutes'] ?? 0,
                isPremium: _isPremium,
                isActive: _isActive,
                categoryName: _categories.firstWhere((cat) => cat['id'] == _selectedCategoryId)['name']!,
                episodes: episodes,
                pdfUploaded: (syncData['pdf_uploaded'] == true),
                pdfSelected: (_selectedPdfFile != null),
                pdfUrl: syncData['pdf_url'],
                pdfSizeBytes: _selectedPdfFile?.size,
                onApprove: () async {
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'youtube-admin-tools?action=approve_playlist',
                      body: {'playlist_id': syncData['playlist_id']},
                    );
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                      String successMessage = '? Playlist approved and published successfully!';
                      if (syncData['pdf_uploaded'] == true) {
                        successMessage = '? Playlist approved and published successfully (with PDF)!';
                      } else if (_selectedPdfFile != null && syncData['pdf_uploaded'] == false) {
                        successMessage = '? Playlist approved! (PDF upload failed - you can add it later)';
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(successMessage), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error approving playlist: ${e.toString()}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
                onReject: () async {
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'youtube-admin-tools?action=delete-kitab',
                      body: {'kitab_id': syncData['playlist_id']},
                    );
                    if (mounted) {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Playlist rejected and removed'), backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error rejecting playlist: ${e.toString()}'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                },
              ),
            );
          }
      }
    } catch (e, stackTrace) {
      print('=== AUTO SYNC ERROR ===');
      print('Error type: ${e.runtimeType}');
      print('Error message: ${e.toString()}');
      print('Stack trace: $stackTrace');
      print('=== AUTO SYNC ERROR END ===');

      if (mounted) {
        // Close loading dialog if open
        Navigator.of(context).pop();

        // Provide user-friendly error messages based on error type
        String userMessage;
        if (e.toString().contains('Failed host lookup') ||
            e.toString().contains('SocketException') ||
            e.toString().contains('No address associated with hostname')) {
          userMessage =
              'Network connection error. Please check your internet connection and try again.';
        } else if (e.toString().contains('timeout') ||
            e.toString().contains('TimeoutException')) {
          userMessage =
              'Request timed out. Please check your connection and try again.';
        } else if (e.toString().contains('403') ||
            e.toString().contains('Forbidden')) {
          userMessage =
              'Access denied. Please check your permissions or try again later.';
        } else if (e.toString().contains('404') ||
            e.toString().contains('Not Found')) {
          userMessage =
              'Service not found. Please try again later or contact support.';
        } else if (e.toString().contains('500') ||
            e.toString().contains('Internal Server Error')) {
          userMessage = 'Server error. Please try again later.';
        } else {
          userMessage = 'Error syncing playlist: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}




