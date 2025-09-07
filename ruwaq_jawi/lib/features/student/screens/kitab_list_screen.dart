import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/models/kitab.dart';
import '../widgets/student_bottom_nav.dart';

class KitabListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSort;
  
  const KitabListScreen({
    super.key,
    this.initialCategory,
    this.initialSort,
  });

  @override
  State<KitabListScreen> createState() => _KitabListScreenState();
}

class _KitabListScreenState extends State<KitabListScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      if (kitabProvider.kitabList.isEmpty) {
        kitabProvider.initialize();
      }
      
      // Set initial category filter if provided
      if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
        _setInitialCategoryFilter(kitabProvider);
      }
    });
  }
  
  void _setInitialCategoryFilter(KitabProvider kitabProvider) {
    final categoryName = Uri.decodeComponent(widget.initialCategory!);
    if (categoryName != 'Semua') {
      try {
        final category = kitabProvider.categories.firstWhere(
          (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
        );
        setState(() {
          _selectedCategoryId = category.id;
        });
      } catch (e) {
        // Category not found, keep default selection
        debugPrint('Category "$categoryName" not found');
        debugPrint('Available categories: ${kitabProvider.categories.map((c) => c.name).join(', ')}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Koleksi Kitab'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.textLightColor,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  // TODO: Implement search
                  context.push('/search');
                },
              ),
            ],
          ),
          body: kitabProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : kitabProvider.errorMessage != null
                  ? _buildErrorState(kitabProvider.errorMessage!)
                  : Column(
                      children: [
                        // Filter and Sort Section
                        _buildFilterSection(kitabProvider),
                        
                        // Content List
                        Expanded(
                          child: _buildKitabGrid(kitabProvider),
                        ),
                      ],
                    ),
          bottomNavigationBar: const StudentBottomNav(currentIndex: 1),
        );
      },
    );
  }

  Widget _buildFilterSection(KitabProvider kitabProvider) {
    final categories = ['Semua', ...kitabProvider.categories.map((c) => c.name)];
    final selectedCategory = _selectedCategoryId == null ? 'Semua' : 
        kitabProvider.categories.firstWhere((c) => c.id == _selectedCategoryId).name;
    
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Category Filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;
                
                return Container(
                  margin: EdgeInsets.only(right: index < categories.length - 1 ? 8 : 0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (category == 'Semua') {
                          _selectedCategoryId = null;
                        } else {
                          _selectedCategoryId = kitabProvider.categories
                              .firstWhere((c) => c.name == category).id;
                        }
                      });
                    },
                    backgroundColor: AppTheme.surfaceColor,
                    selectedColor: AppTheme.primaryColor,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondaryColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                    ),
                  ),
                );
              },
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildKitabGrid(KitabProvider kitabProvider) {
    List<Kitab> filteredKitab = kitabProvider.kitabList.where((kitab) {
      bool categoryMatch = _selectedCategoryId == null || kitab.categoryId == _selectedCategoryId;
      return categoryMatch;
    }).toList();

    // Sort by newest by default
    filteredKitab.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredKitab.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await kitabProvider.refresh();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredKitab.length,
        itemBuilder: (context, index) {
          return _buildKitabCard(filteredKitab[index]);
        },
      ),
    );
  }

  Widget _buildKitabCard(Kitab kitab) {
    return GestureDetector(
      onTap: () => context.push('/kitab/${kitab.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.book,
                        size: 48,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    
                    // Premium Badge
                    if (kitab.isPremium)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PREMIUM',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textPrimaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    
                    // Media Icons
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Row(
                        children: [
                          if (kitab.youtubeVideoId != null)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.play_circle_outline,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          if (kitab.youtubeVideoId != null && kitab.pdfUrl != null)
                            const SizedBox(width: 4),
                          if (kitab.pdfUrl != null)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.picture_as_pdf,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Content Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        kitab.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Flexible(
                      child: Text(
                        kitab.author ?? 'Unknown Author',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    // Show episode count for all kitab
                    Row(
                      children: [
                        Icon(
                          Icons.video_library,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          kitab.hasMultipleVideos && kitab.totalVideos > 0
                              ? '${kitab.totalVideos} episod'
                              : '1 episod',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Tiada kitab ditemui',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuba ubah penapis atau kategori',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedCategoryId = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
            ),
            child: const Text('Reset Penapis'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
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
            'Ralat Memuat Data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.read<KitabProvider>().refresh();
            },
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
}
