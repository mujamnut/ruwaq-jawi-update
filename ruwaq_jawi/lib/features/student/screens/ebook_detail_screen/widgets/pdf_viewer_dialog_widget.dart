import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/models/ebook.dart';

class PDFViewerDialogWidget extends StatefulWidget {
  final Ebook ebook;

  const PDFViewerDialogWidget({super.key, required this.ebook});

  static void show(BuildContext context, Ebook ebook) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => Dialog.fullscreen(
        child: PDFViewerDialogWidget(ebook: ebook),
      ),
    );
  }

  @override
  State<PDFViewerDialogWidget> createState() => _PDFViewerDialogWidgetState();
}

class _PDFViewerDialogWidgetState extends State<PDFViewerDialogWidget> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfViewerController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
    debugPrint('🔍 PDFViewerDialog: Initializing with URL: ${widget.ebook.pdfUrl}');

    // Set timeout for loading - if not loaded in 30 seconds, show error
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isLoading) {
        debugPrint('⏱️ PDFViewerDialog: Loading timeout');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Masa tamat semasa memuat PDF. Sila semak sambungan internet anda.';
        });
      }
    });
  }

  @override
  void dispose() {
    _pdfViewerController?.dispose();
    super.dispose();
  }

  void _onDocumentLoaded(PdfDocumentLoadedDetails details) {
    debugPrint('✅ PDFViewerDialog: Document loaded successfully - ${details.document.pages.count} pages');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    }
  }

  void _onDocumentLoadFailed(PdfDocumentLoadFailedDetails details) {
    debugPrint('❌ PDFViewerDialog: Document load failed - ${details.error}');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = details.error;
      });
    }
  }

  void _retryLoading() {
    debugPrint('🔄 PDFViewerDialog: Retrying to load PDF');
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    // Recreate the key to force widget rebuild
    setState(() {});
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
    return Stack(
      children: [
        // Always render PDF viewer
        SfPdfViewer.network(
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
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Memuatkan PDF...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),

        // Error overlay
        if (_hasError)
          Container(
            color: Colors.black,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage ?? 'Gagal memuat fail PDF',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _retryLoading,
                          icon: PhosphorIcon(PhosphorIcons.arrowClockwise(), color: Colors.white),
                          label: const Text('Cuba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BF6D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: PhosphorIcon(PhosphorIcons.x(), color: Colors.white),
                          label: const Text('Tutup'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}