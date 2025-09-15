import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/ebook.dart';
import '../widgets/student_bottom_nav.dart';

class EbookScreen extends StatefulWidget {
  const EbookScreen({super.key});

  @override
  State<EbookScreen> createState() => _EbookScreenState();
}

class _EbookScreenState extends State<EbookScreen> {
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      bool scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) {
        setState(() {
          _isScrolled = scrolled;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final kitabProvider = context.read<KitabProvider>();
      if (kitabProvider.ebookList.isEmpty) {
        kitabProvider.initialize();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KitabProvider>(
      builder: (context, kitabProvider, child) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: Text(
              'E-Book',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: _isScrolled ? Colors.white : AppTheme.backgroundColor,
            iconTheme: IconThemeData(color: Colors.black),
            elevation: _isScrolled ? 2 : 0,
            centerTitle: false,
            titleSpacing: 20,
          ),
          body: kitabProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : kitabProvider.errorMessage != null
              ? _buildErrorState(kitabProvider.errorMessage!)
              : _buildScrollableContent(kitabProvider),
          bottomNavigationBar: const StudentBottomNav(currentIndex: 2),
        );
      },
    );
  }

  Widget _buildScrollableContent(KitabProvider kitabProvider) {
    // Filter only ebooks from the ebooks table
    List<Ebook> filteredEbooks = kitabProvider.activeEbooks.where((ebook) {
      bool categoryMatch =
          _selectedCategoryId == null ||
          ebook.categoryId == _selectedCategoryId;

      bool searchMatch =
          _searchQuery.isEmpty ||
          ebook.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (ebook.author?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false);

      return categoryMatch && searchMatch;
    }).toList();

    // Sort by newest by default
    filteredEbooks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (filteredEbooks.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),
          SliverFillRemaining(child: _buildEmptyState()),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await kitabProvider.refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search and Filters
          SliverToBoxAdapter(child: _buildSearchAndFilters(kitabProvider)),

          // E-book Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final ebook = filteredEbooks[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + (index * 50)),
                  curve: Curves.easeOutBack,
                  child: _buildEbookCard(ebook),
                );
              }, childCount: filteredEbooks.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(KitabProvider kitabProvider) {
    final categories = [
      'Semua',
      ...kitabProvider.categories.map((c) => c.name),
    ];
    final selectedCategory = _selectedCategoryId == null
        ? 'Semua'
        : kitabProvider.categories
              .firstWhere((c) => c.id == _selectedCategoryId)
              .name;

    return Container(
      color: AppTheme.backgroundColor,
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFEEEEEE),
                hintText: 'Cari e-book yang anda inginkan...',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: PhosphorIcon(
                    PhosphorIcons.magnifyingGlass(),
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: PhosphorIcon(
                          PhosphorIcons.x(),
                          color: AppTheme.textSecondaryColor,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Category Filters
          Container(
            height: 40,
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return Container(
                  margin: EdgeInsets.only(right: 12, bottom: 4),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (category == 'Semua') {
                          _selectedCategoryId = null;
                        } else {
                          _selectedCategoryId = kitabProvider.categories
                              .firstWhere((c) => c.name == category)
                              .id;
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8E8E8)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected
                              ? AppTheme.textPrimaryColor
                              : AppTheme.textSecondaryColor,
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
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


  Widget _buildEbookCard(Ebook ebook) {
    final totalPages = ebook.totalPages ?? 0;
    final fileSize = ebook.pdfFileSize != null
        ? '${(ebook.pdfFileSize! / 1024 / 1024).toStringAsFixed(1)} MB'
        : null;

    return GestureDetector(
      onTap: () => context.push('/ebook/${ebook.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail with gradient and icons
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.15),
                      AppTheme.primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      top: -10,
                      right: -10,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    // Main PDF icon
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIcons.filePdf(),
                            color: AppTheme.primaryColor,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'E-BOOK',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Premium Badge
                    if (ebook.isPremium == true)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: PhosphorIcon(
                            PhosphorIcons.crown(),
                            color: Colors.white,
                            size: 14,
                          ),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ebook.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ebook.author ?? 'Unknown Author',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (totalPages > 0)
                          Row(
                            children: [
                              PhosphorIcon(
                                PhosphorIcons.filePdf(),
                                size: 14,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$totalPages hal',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        if (fileSize != null)
                          Text(
                            fileSize,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppTheme.textSecondaryColor,
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
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: PhosphorIcon(
                PhosphorIcons.filePdf(),
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tiada E-Book Ditemui',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Cuba ubah kategori atau periksa semula untuk melihat e-book yang tersedia',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCategoryId = null;
                });
              },
              icon: PhosphorIcon(
                PhosphorIcons.arrowClockwise(),
                color: AppTheme.textLightColor,
                size: 18,
              ),
              label: const Text('Reset Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: PhosphorIcon(
              PhosphorIcons.warning(),
              size: 64,
              color: AppTheme.errorColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ralat Memuat Data',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              errorMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              context.read<KitabProvider>().refresh();
            },
            icon: PhosphorIcon(
              PhosphorIcons.arrowClockwise(),
              color: AppTheme.textLightColor,
              size: 18,
            ),
            label: const Text('Cuba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: AppTheme.textLightColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }
}
