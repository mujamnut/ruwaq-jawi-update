import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/youtube_sync_loading_dialog.dart';
import '../widgets/youtube_preview_dialog.dart';

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

  String? _selectedCategoryId;
  bool _isPremium = true;
  bool _isActive = true;
  PlatformFile? _selectedPdfFile;

  bool _isLoading = false;

  final List<Map<String, String>> _categories = [
    {'id': 'e1166e04-4f53-4d1a-87b6-e71af547d896', 'name': 'Quran & Tafsir'},
    {'id': 'a39016be-df7a-44a0-859e-7caaa32d8732', 'name': 'Fiqh'},
    {'id': '6e69d652-58b7-4376-b416-a5672f0f7c94', 'name': 'Akidah'},
    {'id': '25004d73-6445-418e-9726-4e1022ff5309', 'name': 'Hadith'},
    {'id': '600baa07-f492-4df1-af75-3127ea151d28', 'name': 'Bahasa Arab'},
    {'id': 'ee66c3d9-74e4-44dd-8761-62ea489b10fb', 'name': 'Akhlak & Tasawuf'},
    {'id': '49819bc9-abaf-4196-8854-e12147c440de', 'name': 'Sirah'},
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
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

  @override
  void dispose() {
    _playlistUrlController.dispose();
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
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
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
                    value: category['id'],
                    child: Text(category['name']!),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPdfFile != null
                          ? Colors.green.withValues(alpha: 0.5)
                          : AppTheme.borderColor,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      PhosphorIcon(
                        _selectedPdfFile != null
                            ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                            : PhosphorIcons.cloudArrowUp(),
                        size: 32,
                        color: _selectedPdfFile != null
                            ? Colors.green
                            : AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 12),
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
                      ),
                      if (_selectedPdfFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${(_selectedPdfFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'PDF files only • Max 50MB',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                      ],
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
                      onPressed: _isLoading ? null : _syncPlaylist,
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
                        _isLoading ? 'Syncing...' : 'Sync Playlist',
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

  Future<bool> _checkNetworkConnectivity() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();

      if (connectivityResults.contains(ConnectivityResult.none) ||
          connectivityResults.isEmpty) {
        return false;
      }

      // Additional DNS check
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

      print('Calling edge function: youtube-playlist-sync-fixed');
      print(
        'Request body: ${{'playlist_url': _playlistUrlController.text, 'category_id': _selectedCategoryId, 'is_premium': _isPremium, 'is_active': _isActive}}',
      );

      // Call YouTube sync API
      final response = await Supabase.instance.client.functions.invoke(
        'youtube-playlist-sync-fixed',
        body: {
          'playlist_url': _playlistUrlController.text,
          'category_id': _selectedCategoryId,
          'is_premium': _isPremium,
          'is_active': _isActive,
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

      final List<VideoEpisodePreview> episodes =
          (syncData['episodes'] as List?)
              ?.map(
                (episode) => VideoEpisodePreview(
                  title: episode['title'] ?? 'Untitled Episode',
                  duration: episode['duration'],
                  isPreview: episode['is_preview'] ?? false,
                ),
              )
              .toList() ??
          [];

      print('Parsed episodes: ${episodes.length}');
      print('=== AUTO SYNC DEBUG SUCCESS ===');

      if (mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show preview dialog
        showDialog(
          context: context,
          builder: (context) => YouTubePreviewDialog(
            playlistTitle: syncData['playlist_title'] ?? 'Unknown Playlist',
            playlistDescription: syncData['playlist_description'],
            channelTitle: syncData['channel_title'],
            totalVideos: syncData['total_videos'] ?? 0,
            totalDurationMinutes: syncData['total_duration_minutes'] ?? 0,
            isPremium: _isPremium,
            isActive: _isActive,
            categoryName: _categories.firstWhere(
              (cat) => cat['id'] == _selectedCategoryId,
            )['name']!,
            episodes: episodes,
            onApprove: () async {
              try {
                print('=== APPROVING PLAYLIST ===');
                print('Playlist ID: ${syncData['playlist_id']}');

                // Approve and publish the playlist
                final approveResponse = await Supabase.instance.client.functions
                    .invoke(
                      'youtube-admin-tools?action=approve_playlist',
                      body: {'playlist_id': syncData['playlist_id']},
                    );

                print('Approve response status: ${approveResponse.status}');
                print('Approve response data: ${approveResponse.data}');
                print('=== PLAYLIST APPROVED ===');

                if (mounted) {
                  Navigator.of(context).pop(); // Close preview
                  Navigator.of(context).pop(); // Go back to main screen

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Playlist approved and published successfully!',
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e, stackTrace) {
                print('=== APPROVAL ERROR ===');
                print('Error: ${e.toString()}');
                print('Stack trace: $stackTrace');
                print('=== APPROVAL ERROR END ===');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error approving playlist: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            onReject: () async {
              try {
                print('=== REJECTING PLAYLIST ===');
                print('Playlist ID: ${syncData['playlist_id']}');

                // Delete the synced playlist
                final rejectResponse = await Supabase.instance.client.functions
                    .invoke(
                      'youtube-admin-tools?action=delete-kitab',
                      body: {'kitab_id': syncData['playlist_id']},
                    );

                print('Reject response status: ${rejectResponse.status}');
                print('Reject response data: ${rejectResponse.data}');
                print('=== PLAYLIST REJECTED ===');

                if (mounted) {
                  Navigator.of(context).pop(); // Close preview

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Playlist rejected and removed'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e, stackTrace) {
                print('=== REJECTION ERROR ===');
                print('Error: ${e.toString()}');
                print('Stack trace: $stackTrace');
                print('=== REJECTION ERROR END ===');

                if (mounted) {
                  Navigator.of(context).pop(); // Close preview anyway

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error rejecting playlist: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
        );
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
