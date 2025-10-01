import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/ebook.dart';

class PDFViewerScreen extends StatefulWidget {
  final Ebook ebook;

  const PDFViewerScreen({
    super.key,
    required this.ebook,
  });

  @override
  State<PDFViewerScreen> createState() => _PDFViewerScreenState();
}

class _PDFViewerScreenState extends State<PDFViewerScreen> with TickerProviderStateMixin {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;
  OverlayEntry? _overlayEntry;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isFullScreen = false;
  bool _showControls = true;
  int _currentPage = 1;
  int _totalPages = 0;

  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();

    // Setup animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    // Auto-hide controls after 3 seconds
    _startAutoHideTimer();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _startAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showControls && _isFullScreen) {
        _toggleControls();
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _fadeController.reverse();
      _startAutoHideTimer();
    } else {
      _fadeController.forward();
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      _showControls = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      _startAutoHideTimer();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _fadeController.reverse();
    }
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _isLoading = false;
      _hasError = false;
      _totalPages = details.document.pages.count;
    });
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = details.error;
    });
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
  }

  void _showPageNavigator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.fileText(),
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pergi ke Halaman',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _currentPage.toDouble(),
                    min: 1,
                    max: _totalPages.toDouble(),
                    divisions: _totalPages - 1,
                    activeColor: AppTheme.primaryColor,
                    inactiveColor: AppTheme.borderColor,
                    onChanged: (value) {
                      setState(() {
                        _currentPage = value.toInt();
                      });
                    },
                    onChangeEnd: (value) {
                      _pdfViewerController?.jumpToPage(value.toInt());
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isFullScreen,
      onPopInvokedWithResult: (didPop, result) {
        if (_isFullScreen && !didPop) {
          _toggleFullScreen();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: _isFullScreen ? null : AppBar(
          title: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.filePdf(),
                color: AppTheme.textLightColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.ebook.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.textLightColor,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.caretLeft(),
              color: AppTheme.textLightColor,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: PhosphorIcon(
                  PhosphorIcons.arrowsOut(),
                  color: AppTheme.textLightColor,
                  size: 20,
                ),
                onPressed: _toggleFullScreen,
                tooltip: 'Skrin Penuh',
              ),
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: _isFullScreen ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Memuatkan E-Book...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sila tunggu sebentar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
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
                'Ralat Memuat E-Book',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Gagal memuat fail PDF',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                icon: PhosphorIcon(
                  PhosphorIcons.caretLeft(),
                  color: AppTheme.textLightColor,
                  size: 18,
                ),
                label: const Text('Kembali'),
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
        ),
      );
    }

    return Stack(
      children: [
        // PDF Viewer
        GestureDetector(
          onTap: _isFullScreen ? _toggleControls : null,
          child: SfPdfViewer.network(
            widget.ebook.pdfUrl,
            key: _pdfViewerKey,
            controller: _pdfViewerController,
            onDocumentLoaded: _onDocumentLoaded,
            onDocumentLoadFailed: _onDocumentLoadFailed,
            onPageChanged: _onPageChanged,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            pageLayoutMode: PdfPageLayoutMode.continuous,
          ),
        ),

        // Full screen controls overlay
        if (_isFullScreen)
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: 1.0 - _fadeAnimation.value,
                child: _showControls ? _buildFullScreenControls() : const SizedBox.shrink(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildFullScreenControls() {
    return SafeArea(
      child: Column(
        children: [
          // Top controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIcons.x(),
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _toggleFullScreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.ebook.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIcons.listNumbers(),
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _showPageNavigator,
                ),
              ],
            ),
          ),
          const Spacer(),
          // Bottom controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Page info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.fileText(),
                    color: AppTheme.primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentPage / $_totalPages',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // Controls
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.listNumbers(),
                      color: AppTheme.textSecondaryColor,
                      size: 20,
                    ),
                    onPressed: _showPageNavigator,
                    tooltip: 'Pergi ke Halaman',
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.arrowsOut(),
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                    onPressed: _toggleFullScreen,
                    tooltip: 'Skrin Penuh',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}