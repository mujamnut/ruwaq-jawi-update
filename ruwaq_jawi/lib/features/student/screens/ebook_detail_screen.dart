import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/app_theme.dart';

// Import managers
import 'ebook_detail_screen/managers/ebook_data_manager.dart';
import 'ebook_detail_screen/managers/ebook_animation_manager.dart';
import 'ebook_detail_screen/managers/ebook_favorites_manager.dart';

// Import services
import 'ebook_detail_screen/services/ebook_premium_service.dart';
import 'ebook_detail_screen/services/ebook_notification_helper.dart';

// Import widgets
import 'ebook_detail_screen/widgets/ebook_loading_screen_widget.dart';
import 'ebook_detail_screen/widgets/ebook_error_screen_widget.dart';
import 'ebook_detail_screen/widgets/ebook_cover_widget.dart';
import 'ebook_detail_screen/widgets/ebook_author_info_widget.dart';
import 'ebook_detail_screen/widgets/ebook_statistics_row_widget.dart';
import 'ebook_detail_screen/widgets/ebook_description_widget.dart';
import 'ebook_detail_screen/widgets/ebook_action_buttons_widget.dart';
import 'ebook_detail_screen/widgets/reading_options_modal_widget.dart';
import 'ebook_detail_screen/widgets/pdf_viewer_dialog_widget.dart';

class EbookDetailScreen extends StatefulWidget {
  final String ebookId;

  const EbookDetailScreen({super.key, required this.ebookId});

  @override
  State<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen>
    with TickerProviderStateMixin {
  // Managers
  late EbookDataManager _dataManager;
  late EbookAnimationManager _animationManager;
  late EbookFavoritesManager _favoritesManager;

  // UI state
  final double _readingProgress = 0.0;
  final double _rating = 4.8;
  final int _reviewsCount = 2847;

  @override
  void initState() {
    super.initState();

    // Initialize managers
    _dataManager = EbookDataManager(onStateChanged: () => setState(() {}));
    _animationManager = EbookAnimationManager();
    _animationManager.initialize(this);
    _favoritesManager =
        EbookFavoritesManager(onStateChanged: () => setState(() {}));

    // Load data
    _loadEbookData();
    _loadSubscriptionData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSubscriptionData();
  }

  @override
  void dispose() {
    _animationManager.dispose();
    super.dispose();
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.loadUserSubscriptions();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading subscription data: $e');
    }
  }

  Future<void> _loadEbookData() async {
    await _dataManager.loadEbookData(context, widget.ebookId);

    if (mounted) {
      await _favoritesManager.checkSavedStatus(context, _dataManager.ebook);

      // Start animations after data loaded
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _animationManager.startAnimations();
        }
      });
    }
  }

  Future<void> _toggleSaved() async {
    final success =
        await _favoritesManager.toggleSaved(context, _dataManager.ebook);

    if (mounted) {
      if (success) {
        EbookNotificationHelper.showSaveSuccess(
            context, _favoritesManager.isSaved);
      } else {
        EbookNotificationHelper.showError(
          context,
          'Gagal ${_favoritesManager.isSaved ? 'mengeluarkan' : 'menyimpan'} e-book',
        );
      }
    }
  }

  void _showReadingOptions() {
    if (_dataManager.ebook!.isPremium &&
        !EbookPremiumService.hasActiveSubscription(context)) {
      EbookPremiumService.showPremiumDialog(context);
      return;
    }

    ReadingOptionsModalWidget.show(
      context,
      onReadOnline: _openPDFViewer,
      onDownload: _downloadEbook,
    );
  }

  void _openPDFViewer() {
    if (_dataManager.ebook!.isPremium &&
        !EbookPremiumService.hasActiveSubscription(context)) {
      EbookPremiumService.showPremiumDialog(context);
      return;
    }

    if (_dataManager.ebook?.pdfUrl == null ||
        _dataManager.ebook!.pdfUrl.trim().isEmpty) {
      EbookNotificationHelper.showError(
          context, 'URL PDF tidak tersedia untuk e-book ini');
      return;
    }

    PDFViewerDialogWidget.show(context, _dataManager.ebook!);
  }

  void _downloadEbook() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Mengunduh e-book...'),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      if (mounted) {
        EbookNotificationHelper.showDownloadSuccess(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen
    if (_dataManager.isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(context),
        body: const EbookLoadingScreenWidget(),
      );
    }

    // Show error screen
    if (_dataManager.error != null || _dataManager.ebook == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _buildAppBar(context),
        body: EbookErrorScreenWidget(errorMessage: _dataManager.error),
      );
    }

    // Show main content
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(context, showSaveButton: true),
      body: _buildMainContent(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context,
      {bool showSaveButton = false}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      leading: IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: AppTheme.textPrimaryColor,
          size: 24,
        ),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Detail E-Book',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
      ),
      centerTitle: true,
      actions: showSaveButton
          ? [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: PhosphorIcon(
                    key: ValueKey(_favoritesManager.isSaved),
                    _favoritesManager.isSaved
                        ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                        : PhosphorIcons.heart(),
                    color: _favoritesManager.isSaved
                        ? const Color(0xFFE91E63)
                        : AppTheme.textSecondaryColor,
                    size: 24,
                  ),
                ),
                onPressed: _toggleSaved,
              ),
            ]
          : null,
    );
  }

  Widget _buildMainContent() {
    return AnimatedBuilder(
      animation: _animationManager.fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _animationManager.fadeAnimation.value.clamp(0.0, 1.0),
          child: SlideTransition(
            position: _animationManager.slideAnimation,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cover
                  EbookCoverWidget(
                    ebook: _dataManager.ebook!,
                    readingProgress: _readingProgress,
                    scaleValue: _animationManager.scaleAnimation.value,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Text(
                          _dataManager.ebook!.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Author info
                  EbookAuthorInfoWidget(
                    ebook: _dataManager.ebook!,
                    rating: _rating,
                    reviewsCount: _reviewsCount,
                  ),
                  const SizedBox(height: 32),

                  // Statistics
                  EbookStatisticsRowWidget(ebook: _dataManager.ebook!),
                  const SizedBox(height: 32),

                  // Description
                  EbookDescriptionWidget(ebook: _dataManager.ebook!),
                  const SizedBox(height: 40),

                  // Action button
                  EbookActionButtonsWidget(
                    ebook: _dataManager.ebook!,
                    isPremiumLocked: _dataManager.ebook!.isPremium &&
                        !EbookPremiumService.hasActiveSubscription(context),
                    onReadingOptions: _showReadingOptions,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}