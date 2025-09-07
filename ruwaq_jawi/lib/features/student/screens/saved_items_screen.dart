import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/providers/bookmark_provider.dart';
import '../../../core/models/kitab.dart';
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
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.textLightColor,
          labelColor: AppTheme.textLightColor,
          unselectedLabelColor: AppTheme.textLightColor.withOpacity(0.7),
          tabs: const [
            Tab(text: 'Kitab'),
            Tab(text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildKitabTab(),
          _buildVideoTab(),
        ],
      ),
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

  // Removed _buildVideoCard as it's not used with real data

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

  // Removed _handleVideoAction as video saving is not implemented yet

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
