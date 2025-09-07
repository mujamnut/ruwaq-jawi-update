import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/models/kitab_video.dart';
import '../widgets/preview_video_selection_dialog.dart';
import '../../../core/widgets/offline_banner.dart';

class KitabDetailScreen extends StatefulWidget {
  final String kitabId;
  
  const KitabDetailScreen({
    super.key,
    required this.kitabId,
  });

  @override
  State<KitabDetailScreen> createState() => _KitabDetailScreenState();
}

class _KitabDetailScreenState extends State<KitabDetailScreen> {
  bool _isSaved = false;
  Kitab? _kitab;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKitabData();
    _checkIfSaved();
  }

  void _loadKitabData() {
    final kitabProvider = context.read<KitabProvider>();
    
    _kitab = kitabProvider.getKitabById(widget.kitabId);
    
    if (_kitab != null) {
      setState(() {
        _isLoading = false;
      });
      _checkIfSaved();
    } else {
      // Defer initialization to after first frame to avoid notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        kitabProvider.initialize().then((_) {
          if (mounted) {
            setState(() {
              _kitab = kitabProvider.getKitabById(widget.kitabId);
              _isLoading = false;
            });
            _checkIfSaved();
          }
        });
      });
    }
  }

  void _checkIfSaved() {
    if (_kitab != null) {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      setState(() {
        _isSaved = savedItemsProvider.isKitabSaved(_kitab!.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textLightColor,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_kitab == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textLightColor,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Kitab tidak ditemui',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildKitabInfo(),
                  const SizedBox(height: 24),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildDescription(),
                  const SizedBox(height: 24),
                  // Episodes section for multi-episode kitab
                  if (_kitab!.hasMultipleVideos) ...[
                    _buildEpisodesSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildRelatedKitab(),
                  const SizedBox(height: 100), // Bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: AppTheme.textLightColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.textLightColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.book,
                    size: 40,
                    color: AppTheme.textLightColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _kitab!.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textLightColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
          onPressed: _toggleSaved,
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: _shareKitab,
        ),
      ],
    );
  }

  Widget _buildKitabInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kitab!.author ?? 'Unknown Author',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Consumer<KitabProvider>(
                    builder: (context, kitabProvider, child) {
                      final category = kitabProvider.categories
                          .where((c) => c.id == _kitab!.categoryId)
                          .firstOrNull;
                      return Text(
                        category?.name ?? 'Uncategorized',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_kitab!.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'PREMIUM',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Stats Row
        Row(
          children: [
            // Show episode count for all kitab
            _buildStatItem(Icons.video_library, 
                _kitab!.hasMultipleVideos && _kitab!.totalVideos > 0
                    ? '${_kitab!.totalVideos}'
                    : '1', 
                'Episod'),
            const SizedBox(width: 24),
            _buildStatItem(Icons.picture_as_pdf, '${_kitab!.totalPages ?? 0}', 'Halaman'),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Media Types
        Row(
          children: [
            if (_kitab!.hasVideo)
              _buildMediaChip(Icons.play_circle_outline, 'Video'),
            if (_kitab!.hasVideo && _kitab!.hasPdf)
              const SizedBox(width: 8),
            if (_kitab!.hasPdf)
              _buildMediaChip(Icons.picture_as_pdf, 'PDF'),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Tags (using category as main tag)
        Consumer<KitabProvider>(
          builder: (context, kitabProvider, child) {
            final category = kitabProvider.categories
                .where((c) => c.id == _kitab!.categoryId)
                .firstOrNull;
            final tags = [
              if (category != null) category.name,
              'Kitab',
              if (_kitab!.isPremium) 'Premium'
            ];
            
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                tag,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryColor),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaChip(IconData icon, String label) {
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

  Widget _buildActionButtons() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;
        
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canAccess ? _startReading : _showSubscriptionDialog,
                icon: Icon(canAccess ? Icons.play_arrow : Icons.lock),
                label: Text(canAccess ? 'Mula Baca' : 'Perlu Langganan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canAccess ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                  foregroundColor: AppTheme.textLightColor,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _previewContent,
              icon: const Icon(Icons.visibility),
              label: const Text('Pratonton'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perihal Kitab',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _kitab!.description ?? 'Tiada penerangan tersedia untuk kitab ini.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodesSection() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Episod (${_kitab!.totalVideos})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                Text(
                  _kitab!.formattedDuration,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<KitabVideo>>(
              future: kitabProvider.loadKitabVideos(_kitab!.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Text(
                      'Tiada episod tersedia',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  );
                }
                
                final episodes = snapshot.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: episodes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final episode = episodes[index];
                    return _buildEpisodeCard(episode, index);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildEpisodeCard(KitabVideo episode, int index) {
    final authProvider = context.read<AuthProvider>();
    final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;
    final isLocked = !canAccess && !episode.isPreview;
    
    return GestureDetector(
      onTap: isLocked ? _showSubscriptionDialog : () => _playEpisode(episode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            // Episode number/thumbnail
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isLocked 
                    ? AppTheme.textSecondaryColor.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: isLocked
                    ? Icon(
                        Icons.lock,
                        color: AppTheme.textSecondaryColor,
                        size: 20,
                      )
                    : Text(
                        '${episode.partNumber}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Episode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          episode.title,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isLocked 
                                ? AppTheme.textSecondaryColor
                                : AppTheme.textPrimaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (episode.isPreview)
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
                  if (episode.description?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      episode.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    episode.formattedDuration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Play button
            Icon(
              isLocked ? Icons.lock : Icons.play_circle_outline,
              color: isLocked ? AppTheme.textSecondaryColor : AppTheme.primaryColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedKitab() {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        // Get related kitab from same category
        final relatedKitab = kitabProvider.kitabList
            .where((k) => k.categoryId == _kitab!.categoryId && k.id != _kitab!.id)
            .take(3)
            .toList();
        
        if (relatedKitab.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kitab Berkaitan',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: relatedKitab.length,
                itemBuilder: (context, index) {
                  final kitab = relatedKitab[index];
                  return Container(
                    width: 200,
                    margin: EdgeInsets.only(right: index < relatedKitab.length - 1 ? 12 : 0),
                    child: GestureDetector(
                      onTap: () => context.push('/kitab/${kitab.id}'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.book,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    kitab.title,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    kitab.author ?? 'Unknown Author',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Removed _buildReviews as it's not used with real data

  Widget _buildFloatingActionButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final canAccess = !_kitab!.isPremium || authProvider.hasActiveSubscription;
        
        if (!canAccess) return const SizedBox.shrink();
        
        return FloatingActionButton.extended(
          onPressed: _startReading,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textLightColor,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Mula'),
        );
      },
    );
  }

  void _toggleSaved() async {
    if (_kitab == null) return;
    
    final savedItemsProvider = context.read<SavedItemsProvider>();
    bool success;
    
    if (_isSaved) {
      success = await savedItemsProvider.removeFromSaved(_kitab!.id);
    } else {
      success = await savedItemsProvider.addToSaved(_kitab!.id);
    }
    
    if (success && mounted) {
      setState(() {
        _isSaved = !_isSaved;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Ditambah ke simpanan' : 'Dikeluarkan dari simpanan'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ralat menyimpan. Sila cuba lagi.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareKitab() {
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan dikongsi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startReading() async {
    // Check internet connection first
    final hasInternet = await requiresInternet(
      context,
      message: 'Membaca kitab memerlukan sambungan internet untuk memuat kandungan.',
    );
    
    if (!hasInternet) return;
    
    if (_kitab!.hasMultipleVideos) {
      // For multi-episode kitab, start with first episode
      context.read<KitabProvider>().loadKitabVideos(_kitab!.id).then((episodes) {
        if (episodes.isNotEmpty) {
          final firstEpisode = episodes.first;
          context.push('/player/${widget.kitabId}?episode=${firstEpisode.id}');
        } else {
          context.push('/player/${widget.kitabId}');
        }
      });
    } else {
      // For single episode kitab, use traditional player
      context.push('/player/${widget.kitabId}');
    }
  }
  
  void _playEpisode(KitabVideo episode) async {
    // Check internet connection first
    final hasInternet = await requiresInternet(
      context,
      message: 'Menonton episod memerlukan sambungan internet.',
    );
    
    if (!hasInternet) return;
    
    context.push('/player/${widget.kitabId}?episode=${episode.id}');
  }

  void _previewContent() async {
    if (_kitab == null) return;
    
    // Check internet connection first
    final hasInternet = await requiresInternet(
      context,
      message: 'Pratonton video memerlukan sambungan internet.',
    );
    
    if (!hasInternet) return;
    
    try {
      print('DEBUG: Checking preview for kitab: ${_kitab!.title} (${_kitab!.id})');
      
      // Check if kitab has preview videos
      final kitabProvider = context.read<KitabProvider>();
      final hasPreview = await kitabProvider.hasPreviewVideos(_kitab!.id);
      
      print('DEBUG: Has preview videos: $hasPreview');
      
      if (!hasPreview && mounted) {
        print('DEBUG: No preview videos found, showing subscription dialog');
        // No preview videos available, show subscription dialog
        _showSubscriptionDialog();
        return;
      }
      
      if (mounted) {
        // Show preview video selection dialog
        showDialog(
          context: context,
          builder: (context) => PreviewVideoSelectionDialog(
            kitabId: _kitab!.id,
            kitab: _kitab!,
          ),
        );
      }
    } catch (e) {
      print('Error checking preview videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat memuat pratonton: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Langganan Diperlukan'),
        content: const Text('Kitab ini memerlukan langganan premium untuk diakses. Ingin melanggan sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/subscription');
            },
            child: const Text('Langgan'),
          ),
        ],
      ),
    );
  }
}
