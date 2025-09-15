import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/providers/bookmark_provider.dart';
import '../../../core/models/kitab.dart';
import '../../../core/services/local_saved_items_service.dart';
import '../widgets/student_bottom_nav.dart';

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedItemsProvider>().loadSavedItems();
      // Also load bookmarks so the Video tab (sourced from bookmarks) has data
      final bm = context.read<BookmarkProvider>();
      if (!bm.isLoading && bm.bookmarks.isEmpty) {
        bm.loadBookmarks();
      }
      
      // Add test data for demonstration
      _addTestData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addTestData() async {
    try {
      final provider = context.read<SavedItemsProvider>();
      
      // Add sample kitab data untuk test
      final sampleKitab = Kitab(
        id: 'test_kitab_1',
        title: 'Kitab Test Simpanan',
        author: 'Penulis Test',
        description: 'Ini adalah kitab test untuk local storage',
        thumbnailUrl: '',
        categoryId: 'test_category',
        isActive: true,
        isPremium: false,
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await provider.addKitabToLocal(sampleKitab);
      
      // Add sample video data untuk test  
      await LocalSavedItemsService.saveVideo({
        'kitabId': 'test_kitab_1',
        'episodeId': 'test_episode_1',
        'title': 'Video Test Simpanan',
        'description': 'Video test untuk local storage',
        'createdAt': DateTime.now().toIso8601String(),
      });
      
      print('Test data added successfully');
    } catch (e) {
      print('Error adding test data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalVideos() async {
    try {
      return await LocalSavedItemsService.getSavedVideos();
    } catch (e) {
      print('Error loading local videos: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Simpanan'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.arrowLeft(),
            color: AppTheme.textLightColor,
            size: 20,
          ),
          onPressed: () => context.go('/home'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.textLightColor,
          labelColor: AppTheme.textLightColor,
          unselectedLabelColor: AppTheme.textLightColor.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Kitab & Video'),
            Tab(text: 'E-book'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKitabAndVideoTab(),
          _buildEbookTab(),
        ],
      ),
    );
  }

  Widget _buildKitabAndVideoTab() {
    return Consumer2<SavedItemsProvider, BookmarkProvider>(
      builder: (context, savedItemsProvider, bookmarkProvider, child) {
        final isLoading = savedItemsProvider.isLoading || bookmarkProvider.isLoading;
        
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final savedKitabs = savedItemsProvider.savedKitab;
        final videoBookmarks = bookmarkProvider.getBookmarksByType('video');

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadLocalVideos(),
          builder: (context, snapshot) {
            final localVideos = snapshot.data ?? [];
            final allVideos = [...videoBookmarks, ...localVideos];
            
            final hasItems = savedKitabs.isNotEmpty || allVideos.isNotEmpty;
            
            if (!hasItems) {
              return _buildEmptyState('Tiada simpanan', 'Simpan kitab dan video kegemaran anda untuk akses mudah');
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (savedKitabs.isNotEmpty) ...[
                    Text('Kitab', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...savedKitabs.map((kitab) => _buildKitabCard(kitab)),
                    const SizedBox(height: 16),
                  ],
                  if (allVideos.isNotEmpty) ...[
                    Text('Video', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...allVideos.map((video) => _buildVideoCard(video)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKitabTab() {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        if (savedItemsProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (savedItemsProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ralat memuatkan simpanan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  savedItemsProvider.error!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => savedItemsProvider.loadSavedItems(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                  ),
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          );
        }

        if (savedItemsProvider.savedKitab.isEmpty) {
          return _buildEmptyState('Tiada kitab disimpan', 'Simpan kitab kegemaran anda untuk akses mudah');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: savedItemsProvider.savedKitab.length,
          itemBuilder: (context, index) {
            return _buildKitabCard(savedItemsProvider.savedKitab[index]);
          },
        );
      },
    );
  }

  Widget _buildVideoTab() {
    return Consumer<BookmarkProvider>(
      builder: (context, bmProvider, child) {
        if (bmProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (bmProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.textSecondaryColor),
                const SizedBox(height: 16),
                Text('Ralat memuatkan video disimpan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimaryColor)),
                const SizedBox(height: 8),
                Text(bmProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondaryColor),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => bmProvider.loadBookmarks(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textLightColor,
                  ),
                  child: const Text('Cuba Lagi'),
                ),
              ],
            ),
          );
        }

        final videos = bmProvider.getBookmarksByType('video');
        if (videos.isEmpty) {
          return _buildEmptyState('Tiada video disimpan', 'Simpan video kegemaran anda untuk tontonan kemudian');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final v = videos[index];
            final title = v.title.isNotEmpty ? v.title : 'Tanpa Tajuk';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: InkWell(
                onTap: () {
                  // Open the content player for this kitab and show the video tab
                  context.push('/player/${v.kitabId}');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kitab: ${v.kitabId}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'remove') {
                            final ok = await context.read<BookmarkProvider>().removeBookmark(v.kitabId);
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Video dibuang dari simpanan')),
                              );
                            }
                          } else if (value == 'share') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Pautan "${title}" dikongsi')),
                            );
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [Icon(Icons.bookmark_remove), SizedBox(width: 8), Text('Buang')],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [Icon(Icons.share), SizedBox(width: 8), Text('Kongsi')],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKitabCard(Kitab kitab) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () => context.push('/kitab/${kitab.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.book,
                  color: AppTheme.primaryColor,
                  size: 30,
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
                            kitab.title,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),
                        if (kitab.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PREMIUM',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textLightColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kitab.author ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<SavedItemsProvider>(
                      builder: (context, provider, child) {
                        // Get category name from provider
                        return Text(
                          'Category',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                        );
                      },
                    ),
                    if (kitab.durationMinutes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${kitab.durationMinutes} min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleKitabAction(value, kitab),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.bookmark_remove),
                        SizedBox(width: 8),
                        Text('Buang dari simpanan'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Kongsi'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEbookTab() {
    // For now, show placeholder for e-book saved items
    // This will need to be connected to actual e-book saved items provider
    return _buildEmptyState('Tiada e-book disimpan', 'Simpan e-book kegemaran anda untuk akses mudah');
  }

  Widget _buildVideoCard(dynamic bookmark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.play_circle_outline,
            color: AppTheme.primaryColor,
            size: 32,
          ),
        ),
        title: Text(
          bookmark is Map ? (bookmark['title'] ?? 'Video') : (bookmark.title ?? 'Video'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Video tersimpan',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleVideoAction(value, bookmark),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Buang'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Kongsi'),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to video player
          final kitabId = bookmark is Map ? bookmark['kitabId'] : bookmark.kitabId;
          final episodeId = bookmark is Map ? bookmark['episodeId'] : bookmark.episodeId;
          context.push('/video/$kitabId?episode=$episodeId');
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/kitab'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
            ),
            child: const Text('Jelajah Kitab'),
          ),
        ],
      ),
    );
  }

  void _handleKitabAction(String action, Kitab kitab) {
    switch (action) {
      case 'remove':
        _removeFromSaved(kitab);
        break;
      case 'share':
        _shareContent(kitab);
        break;
    }
  }

  void _handleVideoAction(String action, dynamic bookmark) {
    switch (action) {
      case 'remove':
        _removeVideoBookmark(bookmark);
        break;
      case 'share':
        _shareVideoContent(bookmark);
        break;
    }
  }

  void _removeVideoBookmark(dynamic bookmark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: Text('Adakah anda pasti ingin membuang video ini dari simpanan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final kitabId = bookmark is Map ? bookmark['kitabId'] : bookmark.kitabId;
              final success = await context.read<BookmarkProvider>().removeBookmark(kitabId);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Video dibuang dari simpanan'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
  }

  void _shareVideoContent(dynamic bookmark) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pautan video dikongsi'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _removeFromSaved(Kitab kitab) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buang dari Simpanan'),
        content: Text('Adakah anda pasti ingin membuang "${kitab.title}" dari simpanan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await context.read<SavedItemsProvider>().removeFromSaved(kitab.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${kitab.title} dibuang dari simpanan'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
  }

  void _shareContent(Kitab kitab) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pautan "${kitab.title}" dikongsi'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
