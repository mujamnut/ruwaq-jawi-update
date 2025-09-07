import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/kitab_video.dart';

class PreviewVideoPlayerScreen extends StatefulWidget {
  final String kitabId;
  final String? videoId; // Specific preview video ID

  const PreviewVideoPlayerScreen({
    super.key,
    required this.kitabId,
    this.videoId,
  });

  @override
  State<PreviewVideoPlayerScreen> createState() => _PreviewVideoPlayerScreenState();
}

class _PreviewVideoPlayerScreenState extends State<PreviewVideoPlayerScreen>
    with TickerProviderStateMixin {
  YoutubePlayerController? _controller;
  late TabController _tabController;
  bool _isLoading = true;
  
  Kitab? _kitab;
  List<KitabVideo> _previewVideos = [];
  KitabVideo? _currentVideo;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreviewData();
    });
  }

  Future<void> _loadPreviewData() async {
    try {
      final kitabProvider = context.read<KitabProvider>();
      
      // Get kitab data
      _kitab = kitabProvider.getKitabById(widget.kitabId);
      if (_kitab == null) {
        await kitabProvider.initialize();
        _kitab = kitabProvider.getKitabById(widget.kitabId);
      }
      
      if (_kitab == null) {
        throw Exception('Kitab not found');
      }
      
      // Load preview videos
      _previewVideos = await kitabProvider.loadPreviewVideos(widget.kitabId);
      
      if (_previewVideos.isEmpty) {
        throw Exception('No preview videos available');
      }
      
      // Find current video to play
      if (widget.videoId != null) {
        _currentVideo = _previewVideos.firstWhere(
          (video) => video.id == widget.videoId,
          orElse: () => _previewVideos.first,
        );
      } else {
        _currentVideo = _previewVideos.first;
      }
      
      // Initialize player
      await _initPlayer();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading preview data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog(e.toString());
      }
    }
  }

  Future<void> _initPlayer() async {
    if (_currentVideo == null) return;
    
    _controller = YoutubePlayerController(
      initialVideoId: _currentVideo!.youtubeVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        enableCaption: true,
        controlsVisibleAtStart: true,
        forceHD: false,
        hideControls: false,
        disableDragSeek: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ralat'),
        content: Text('Gagal memuat pratonton: $message'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pratonton Selesai'),
        content: const Text(
          'Pratonton telah selesai. Untuk menonton video penuh, sila langgan premium.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
            ),
            child: const Text('Langgan Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          title: const Text('Memuat Pratonton...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_kitab == null || _controller == null || _currentVideo == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.backgroundColor,
          foregroundColor: AppTheme.textPrimaryColor,
          elevation: 0,
          title: const Text('Ralat'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Gagal memuat pratonton', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: AppTheme.primaryColor,
        onReady: () {},
        onEnded: (_) {
          // Show subscription prompt when preview ends
          _showSubscriptionPrompt();
        },
        bottomActions: [
          CurrentPosition(),
          ProgressBar(isExpanded: true),
          RemainingDuration(),
          FullScreenButton(),
        ],
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundColor,
            foregroundColor: AppTheme.textPrimaryColor,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PRATONTON',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentVideo!.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/subscription'),
                tooltip: 'Langgan Premium',
              ),
            ],
          ),
          body: Column(
            children: [
              // Video Player
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: player,
                ),
              ),
              
              // Preview Notice Banner
              Container(
                width: double.infinity,
                color: AppTheme.secondaryColor.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ini adalah pratonton. Langgan premium untuk menonton video penuh.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: AppTheme.textLightColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: const Size(60, 24),
                      ),
                      child: Text(
                        'Langgan',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textLightColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab Bar
              Container(
                color: AppTheme.backgroundColor,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondaryColor,
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: [
                    Tab(text: 'Pratonton (${_previewVideos.length})'),
                    const Tab(text: 'Info Kitab'),
                  ],
                ),
              ),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPreviewVideosTab(),
                    _buildKitabInfoTab(),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomActionBar(),
        );
      },
    );
  }

  Widget _buildPreviewVideosTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video Pratonton Tersedia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 16),
          
          if (_previewVideos.isEmpty) 
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Center(
                child: Text(
                  'Tiada pratonton tersedia untuk kitab ini',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._previewVideos.map((video) => _buildPreviewVideoCard(video)).toList(),
        ],
      ),
    );
  }

  Widget _buildPreviewVideoCard(KitabVideo video) {
    final isCurrentVideo = _currentVideo?.id == video.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCurrentVideo 
            ? AppTheme.primaryColor.withOpacity(0.1)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentVideo 
              ? AppTheme.primaryColor
              : AppTheme.borderColor,
          width: isCurrentVideo ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isCurrentVideo ? null : () => _switchToVideo(video),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isCurrentVideo
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: isCurrentVideo
                      ? const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        )
                      : Text(
                          '${video.partNumber}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            video.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: isCurrentVideo ? FontWeight.bold : FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'PREVIEW',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.formattedDuration,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (isCurrentVideo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'SEMASA',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.play_circle_outline,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKitabInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _kitab!.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _kitab!.author ?? 'Unknown Author',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          
          // Stats
          Row(
            children: [
              _buildStatChip(Icons.access_time, _kitab!.formattedDuration),
              const SizedBox(width: 12),
              _buildStatChip(Icons.video_library, '${_kitab!.totalVideos} Video'),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            'Perihal Kitab',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _kitab!.description ?? 'Tiada penerangan tersedia.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 24),
          
          // Call to action
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.star_outline,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Suka dengan pratonton ini?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Langgan premium untuk mengakses semua video penuh dan kitab lain.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.push('/subscription'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('Langgan Sekarang'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimaryColor,
                side: BorderSide(color: AppTheme.borderColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Tutup Pratonton'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.push('/subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Langgan Premium'),
            ),
          ),
        ],
      ),
    );
  }

  void _switchToVideo(KitabVideo video) async {
    if (_currentVideo?.id == video.id) return;
    
    // Dispose current controller
    _controller?.dispose();
    
    // Update current video
    setState(() {
      _currentVideo = video;
    });
    
    // Initialize new player
    await _initPlayer();
    
    setState(() {});
  }
}
