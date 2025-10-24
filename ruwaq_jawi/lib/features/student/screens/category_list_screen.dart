import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/kitab_provider.dart';
import 'student_home_screen/widgets/category_icon_card_widget.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _scrollController.addListener(() {
      bool scrolled = _scrollController.offset > 10;
      if (scrolled != _isScrolled) {
        setState(() => _isScrolled = scrolled);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: Consumer<KitabProvider>(
        builder: (context, kitabProvider, child) {
          if (kitabProvider.isLoading) {
            return _buildLoadingState();
          }

          final categories = kitabProvider.categories;

          return RefreshIndicator(
            onRefresh: () async {
              await kitabProvider.refresh();
              if (mounted) {
                _animationController.reset();
                _animationController.forward();
              }
            },
            color: AppTheme.primaryColor,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.86,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];

                    // Count total items (video kitab + ebooks)
                    final videoKitabCount = kitabProvider.activeVideoKitab
                        .where((k) => k.categoryId == category.id)
                        .length;
                    final ebookCount = kitabProvider.activeEbooks
                        .where((e) => e.categoryId == category.id)
                        .length;
                    final totalCount = videoKitabCount + ebookCount;

                    return CategoryIconCardWidget(
                      category: category,
                      totalCount: totalCount,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _isScrolled
          ? AppTheme.surfaceColor.withValues(alpha: 0.95)
          : Colors.transparent,
      elevation: _isScrolled ? 1 : 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: IconButton(
        icon: PhosphorIcon(
          PhosphorIcons.arrowLeft(),
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Semua Kategori',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      centerTitle: false,
    );
  }


  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.86,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // circular icon skeleton
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.borderColor.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: AppTheme.borderColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}
