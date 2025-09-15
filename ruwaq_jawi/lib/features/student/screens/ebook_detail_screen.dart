import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/providers/saved_items_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/ebook.dart';
import '../../../core/services/supabase_service.dart';
import '../widgets/student_bottom_nav.dart';

class EbookDetailScreen extends StatefulWidget {
  final String ebookId;

  const EbookDetailScreen({super.key, required this.ebookId});

  @override
  State<EbookDetailScreen> createState() => _EbookDetailScreenState();
}

class _EbookDetailScreenState extends State<EbookDetailScreen> {
  Ebook? _ebook;
  bool _isLoading = true;
  String? _error;
  bool _isSaved = false;
  double _readingProgress = 0.0;
  double _rating = 4.8;
  int _reviewsCount = 2847;

  @override
  void initState() {
    super.initState();
    _loadEbookData();
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    if (_ebook != null) {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      final saved = await savedItemsProvider.isEbookSaved(_ebook!.id);
      if (mounted) {
        setState(() {
          _isSaved = saved;
        });
      }
    }
  }

  Future<void> _loadEbookData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final kitabProvider = context.read<KitabProvider>();

      // Find ebook from provider first
      Ebook? ebook = kitabProvider.activeEbooks
          .where((e) => e.id == widget.ebookId)
          .firstOrNull;

      // If not found in provider, fetch from database
      if (ebook == null) {
        final response = await SupabaseService.from('ebooks')
            .select('''
              *,
              categories (
                id, name, description
              )
            ''')
            .eq('id', widget.ebookId)
            .single();

        ebook = Ebook.fromJson(response);
      }

      if (mounted) {
        setState(() {
          _ebook = ebook;
          _isLoading = false;
        });
        await _checkSavedStatus();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ralat memuatkan e-book: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  String _getEstimatedReadingTime(int pages) {
    // Anggap 2 minit per halaman secara purata
    final totalMinutes = pages * 2;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}j ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _getReadingLevel() {
    // Boleh jadi dinamik berdasarkan data ebook pada masa hadapan
    return 'Pemula';
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            PhosphorIcon(
              PhosphorIcons.crown(),
              color: Colors.amber,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Premium Content'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anda perlu melanggan untuk mengakses content premium ini.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIcons.lightbulb(),
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Dapatkan akses tidak terhad ke semua content premium!',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to subscription screen
              _navigateToSubscription();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Langgan Sekarang'),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription() {
    // Navigate to subscription screen
    context.push('/subscription');
  }

  Future<void> _toggleSaved() async {
    if (_ebook == null) return;

    try {
      final savedItemsProvider = context.read<SavedItemsProvider>();
      bool success;

      if (_isSaved) {
        success = await savedItemsProvider.removeEbookFromLocal(_ebook!.id);
      } else {
        success = await savedItemsProvider.addEbookToLocal(_ebook!);
      }

      if (success) {
        setState(() {
          _isSaved = !_isSaved;
        });

        _showSnackBar(
          _isSaved
              ? 'Successfully add to favorite'
              : 'Successfully remove to favorite',
          isError: false,
        );
      } else {
        _showSnackBar(
          'Gagal ${_isSaved ? 'mengeluarkan' : 'menyimpan'} e-book',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('Ralat: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showReadingOptions(BuildContext context) {
    // Check if ebook is premium and user doesn't have subscription
    if (_ebook!.isPremium && !_hasActiveSubscription()) {
      _showPremiumDialog();
      return;
    }

    _showReadingOptionsModal(context);
  }

  bool _hasActiveSubscription() {
    // TODO: Implement real subscription check
    // For now, return false to show premium dialog
    return false;
  }

  void _showReadingOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Pilihan Pembacaan',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIcons.readCvLogo(),
                color: AppTheme.primaryColor,
              ),
              title: const Text('Baca Online'),
              subtitle: const Text('Baca langsung di aplikasi'),
              onTap: () {
                Navigator.pop(context);
                _openPDFViewer();
              },
            ),
            ListTile(
              leading: PhosphorIcon(
                PhosphorIcons.download(),
                color: AppTheme.primaryColor,
              ),
              title: const Text('Download & Baca'),
              subtitle: const Text('Download untuk membaca offline'),
              onTap: () {
                Navigator.pop(context);
                _downloadEbook();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openPDFViewer() {
    // Check premium access
    if (_ebook!.isPremium && !_hasActiveSubscription()) {
      _showPremiumDialog();
      return;
    }

    if (_ebook?.pdfUrl == null || _ebook!.pdfUrl.trim().isEmpty) {
      _showSnackBar('URL PDF tidak tersedia untuk e-book ini', isError: true);
      return;
    }

    // Navigate to fullscreen PDF viewer
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) =>
          Dialog.fullscreen(child: PDFViewerDialog(ebook: _ebook!)),
    );
  }

  void _downloadEbook() {
    // Tunjuk progress download
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

    // Simulasi proses download
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pop(context);
      if (mounted) {
        _showSnackBar('E-book berjaya diunduh', isError: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Detail E-Book',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: PhosphorIcon(
                PhosphorIcons.heart(),
                color: Colors.black,
                size: 20,
              ),
              onPressed: () {},
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const CircularProgressIndicator(
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
            ],
          ),
        ),
      );
    }

    if (_error != null || _ebook == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: PhosphorIcon(
              PhosphorIcons.arrowLeft(),
              color: Colors.black,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                    PhosphorIcons.warningCircle(),
                    size: 64,
                    color: AppTheme.errorColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'E-Book Tidak Dijumpai',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? 'E-book yang anda cari tidak wujud',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: PhosphorIcon(
                    PhosphorIcons.arrowLeft(),
                    color: AppTheme.textLightColor,
                    size: 18,
                  ),
                  label: const Text('Kembali'),
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
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.caretLeft(), color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Detail E-Book',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: PhosphorIcon(
                _isSaved
                    ? PhosphorIcons.heart(PhosphorIconsStyle.fill)
                    : PhosphorIcons.heart(),
                color: _isSaved ? Colors.red : Colors.black54,
                size: 20,
              ),
              onPressed: _toggleSaved,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // E-book Cover dengan Progress dan Premium Badge
            _buildEbookCover(),
            const SizedBox(height: 24),

            // Tajuk E-book
            Text(
              _ebook!.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Info Pengarang dengan Avatar
            _buildAuthorInfo(),
            const SizedBox(height: 24),

            // Baris Statistik
            _buildStatisticsRow(),
            const SizedBox(height: 24),

            // Bahagian Deskripsi
            if (_ebook!.description != null &&
                _ebook!.description!.trim().isNotEmpty)
              _buildDescription(),

            const SizedBox(height: 32),

            // Butang Aksi
            _buildActionButtons(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: const StudentBottomNav(currentIndex: 2),
    );
  }

  Widget _buildEbookCover() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 200,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _ebook!.thumbnailUrl != null
                ? CachedNetworkImage(
                    imageUrl: _ebook!.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      child: PhosphorIcon(
                        PhosphorIcons.filePdf(),
                        size: 60,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                        ),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIcons.filePdf(),
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                      ),
                    ),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIcons.filePdf(),
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
          ),
        ),
        // Premium Badge
        if (_ebook!.isPremium)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Premium',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        // Progress Bar
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _readingProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(_readingProgress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: PhosphorIcon(
              PhosphorIcons.student(),
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ebook!.author ?? 'Unknown Author',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.star(PhosphorIconsStyle.fill),
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _rating.toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_reviewsCount reviews',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: PhosphorIcons.fileText(),
            label: 'Halaman',
            value: _ebook!.totalPages?.toString() ?? '0',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: PhosphorIcons.clock(),
            label: 'Durasi',
            value: _getEstimatedReadingTime(_ebook!.totalPages ?? 0),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: PhosphorIcons.trendUp(),
            label: 'Level',
            value: _getReadingLevel(),
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required PhosphorIconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          PhosphorIcon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Deskripsi E-Book',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _ebook!.description!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          _showReadingOptions(context);
        },
        icon: PhosphorIcon(
          PhosphorIcons.readCvLogo(),
          color: Colors.white,
          size: 20,
        ),
        label: Text(
          _ebook!.isPremium && !_hasActiveSubscription()
              ? 'LANGGAN UNTUK BACA'
              : 'BACA SEKARANG',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _ebook!.isPremium && !_hasActiveSubscription()
              ? Colors.grey[400]
              : AppTheme.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: AppTheme.primaryColor.withOpacity(0.3),
        ),
      ),
    );
  }

}

// PDF Viewer Dialog Component
class PDFViewerDialog extends StatefulWidget {
  final Ebook ebook;

  const PDFViewerDialog({super.key, required this.ebook});

  @override
  State<PDFViewerDialog> createState() => _PDFViewerDialogState();
}

class _PDFViewerDialogState extends State<PDFViewerDialog> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    setState(() {
      _isLoading = false;
      _hasError = false;
    });
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    setState(() {
      _isLoading = false;
      _hasError = true;
      _errorMessage = details.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.ebook.title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.x(), color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildPDFViewer(),
    );
  }

  Widget _buildPDFViewer() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Memuatkan PDF...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PhosphorIcon(
              PhosphorIcons.warningCircle(),
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ralat Memuat PDF',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Gagal memuat fail PDF',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SfPdfViewer.network(
      widget.ebook.pdfUrl,
      key: _pdfViewerKey,
      controller: _pdfViewerController,
      onDocumentLoaded: _onDocumentLoaded,
      onDocumentLoadFailed: _onDocumentLoadFailed,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      pageLayoutMode: PdfPageLayoutMode.continuous,
    );
  }
}
