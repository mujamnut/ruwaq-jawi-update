import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../../config/youtube_api.dart';
import '../../../core/models/video_episode.dart';
import '../../../core/services/video_episode_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminEpisodeFormScreen extends StatefulWidget {
  final String videoKitabId;
  final VideoEpisode? episode; // null for add new, filled for edit
  final String? videoKitabTitle; // for display purposes

  const AdminEpisodeFormScreen({
    super.key,
    required this.videoKitabId,
    this.episode,
    this.videoKitabTitle,
  });

  @override
  State<AdminEpisodeFormScreen> createState() => _AdminEpisodeFormScreenState();
}

class _AdminEpisodeFormScreenState extends State<AdminEpisodeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  final _partNumberController = TextEditingController();
  final _durationController = TextEditingController();

  bool _isLoading = false;
  bool _isActive = true;
  bool _isPreview = false;
  String? _extractedVideoId;
  String? _thumbnailUrl;

  bool get _isEditing => widget.episode != null;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() async {
    if (_isEditing && widget.episode != null) {
      final episode = widget.episode!;
      _titleController.text = episode.title;
      _descriptionController.text = episode.description ?? '';
      _youtubeUrlController.text = episode.youtubeVideoUrl ?? episode.youtubeWatchUrl;
      _partNumberController.text = episode.partNumber.toString();
      _durationController.text = episode.durationMinutes.toString();
      _isActive = episode.isActive;
      _isPreview = episode.isPreview;
      _extractedVideoId = episode.youtubeVideoId;
      _thumbnailUrl = episode.actualThumbnailUrl;
    } else {
      // For new episode, get next part number
      try {
        final nextPartNumber = await VideoEpisodeService.getNextPartNumber(widget.videoKitabId);
        _partNumberController.text = nextPartNumber.toString();
      } catch (e) {
        _partNumberController.text = '1';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _partNumberController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _onYouTubeUrlChanged(String value) {
    final videoId = VideoEpisodeService.extractYouTubeVideoId(value);
    setState(() {
      _extractedVideoId = videoId;
      _thumbnailUrl = videoId != null 
          ? VideoEpisodeService.getYouTubeThumbnailUrl(videoId)
          : null;
    });
    
    // Auto-detect video duration
    if (videoId != null) {
      _detectVideoDurationFromYouTube(value);
    }
  }

  Future<void> _saveEpisode() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_extractedVideoId == null) {
      _showSnackBar('Sila masukkan URL YouTube yang sah', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final episodeData = {
        'video_kitab_id': widget.videoKitabId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'youtube_video_id': _extractedVideoId!,
        'youtube_video_url': _youtubeUrlController.text.trim(),
        'thumbnail_url': _thumbnailUrl,
        'part_number': int.parse(_partNumberController.text.trim()),
        'duration_minutes': int.tryParse(_durationController.text.trim()) ?? 0,
        'is_active': _isActive,
        'is_preview': _isPreview,
      };

      if (_isEditing) {
        await VideoEpisodeService.updateEpisode(widget.episode!.id, episodeData);
        _showSnackBar('Episode berjaya dikemaskini!');
      } else {
        await VideoEpisodeService.createEpisode(episodeData);
        _showSnackBar('Episode baru berjaya ditambah!');
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnackBar('Ralat menyimpan episode: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _previewVideo() {
    if (_extractedVideoId != null) {
      final youtubeUrl = VideoEpisodeService.getYouTubeWatchUrl(_extractedVideoId!);
      _launchUrl(youtubeUrl);
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // YouTube duration detection methods
  Future<void> _detectVideoDurationFromYouTube(String youTubeUrl) async {
    // Check if YouTube API is configured
    if (!YouTubeApiConfig.isEnabled) {
      return; // Silently skip if not configured
    }

    try {
      // Extract video ID from YouTube URL
      final videoId = VideoEpisodeService.extractYouTubeVideoId(youTubeUrl);
      if (videoId == null) return;

      // Call YouTube Data API to get video duration
      final url = YouTubeApiConfig.getVideoDetailsUrl(videoId);
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['items'] != null && data['items'].isNotEmpty) {
          final duration = data['items'][0]['contentDetails']['duration'];
          final durationInMinutes = _parseDurationToMinutes(duration);
          
          // Update duration field
          setState(() {
            _durationController.text = durationInMinutes.toString();
          });
          
          _showSnackBar('Durasi video dikesan: $durationInMinutes minit', isError: false);
        }
      }
    } catch (e) {
      // Silently fail - don't bother user with API errors
      print('Could not detect video duration: $e');
    }
  }

  int _parseDurationToMinutes(String duration) {
    // Parse ISO 8601 duration format (PT#M#S)
    final regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    final match = regex.firstMatch(duration);
    
    if (match != null) {
      final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
      
      return hours * 60 + minutes + (seconds > 0 ? 1 : 0); // Round up if has seconds
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Episode' : 'Tambah Episode Baru'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveEpisode,
              child: Text(
                _isEditing ? 'Kemaskini' : 'Simpan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Kitab Info
              if (widget.videoKitabTitle != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedVideo01, color: AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Video Kitab: ${widget.videoKitabTitle}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Basic Information Section
              _buildSectionTitle('Maklumat Asas Episode'),
              const SizedBox(height: 16),
              
              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tajuk Episode *',
                  border: OutlineInputBorder(),
                  prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedAlignLeft, color: Colors.grey),
                  hintText: 'Contoh: Pengenalan Bacaan Jawi',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tajuk episode tidak boleh kosong';
                  }
                  return null;
                },
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Part Number and Duration Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _partNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Nombor Bahagian *',
                        border: OutlineInputBorder(),
                        prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedTextNumberSign, color: Colors.grey),
                        hintText: 'Contoh: 1',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nombor bahagian diperlukan';
                        }
                        final number = int.tryParse(value.trim());
                        if (number == null || number <= 0) {
                          return 'Masukkan nombor yang sah';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Durasi (minit)',
                        border: OutlineInputBorder(),
                        prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Colors.grey),
                        hintText: 'Auto-dikesan dari URL YouTube',
                        helperText: 'Akan cuba mengesan durasi secara automatik',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final number = int.tryParse(value.trim());
                          if (number == null || number < 0) {
                            return 'Masukkan nombor yang sah';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Penerangan Episode',
                  border: OutlineInputBorder(),
                  prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedFile01, color: Colors.grey),
                  alignLabelWithHint: true,
                  hintText: 'Penerangan ringkas tentang kandungan episode ini...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // YouTube Video Section
              _buildSectionTitle('Video YouTube'),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _youtubeUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL atau ID Video YouTube *',
                  border: OutlineInputBorder(),
                  prefixIcon: const HugeIcon(icon: HugeIcons.strokeRoundedCameraVideo, color: Colors.grey),
                  hintText: 'https://www.youtube.com/watch?v=... atau ID video',
                ),
                onChanged: _onYouTubeUrlChanged,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'URL atau ID video YouTube diperlukan';
                  }
                  if (_extractedVideoId == null) {
                    return 'URL YouTube tidak sah';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Video Preview
              if (_extractedVideoId != null && _thumbnailUrl != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedView, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Preview Video',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _previewVideo,
                            icon: const HugeIcon(icon: HugeIcons.strokeRoundedPlay, color: Colors.white),
                            label: const Text('Tonton'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const HugeIcon(icon: HugeIcons.strokeRoundedAlert02, color: Colors.grey),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Video ID: $_extractedVideoId',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'YouTube URL yang dikesan dan sah',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Settings Section
              _buildSectionTitle('Tetapan Episode'),
              const SizedBox(height: 16),

              // Active Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isActive ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedViewOff,
                      color: _isActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Aktif',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isActive 
                                ? 'Episode ini akan ditunjukkan kepada pengguna' 
                                : 'Episode ini akan disembunyikan dari pengguna',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Preview Toggle
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isPreview ? HugeIcons.strokeRoundedView : HugeIcons.strokeRoundedLockPassword,
                      color: _isPreview ? Colors.orange : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Preview',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isPreview 
                                ? 'Episode ini boleh ditonton oleh pengguna percuma sebagai preview' 
                                : 'Episode ini hanya untuk pengguna premium',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isPreview,
                      onChanged: (value) {
                        setState(() {
                          _isPreview = value;
                        });
                      },
                      activeColor: Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }
}
