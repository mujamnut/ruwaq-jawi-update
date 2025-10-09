import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/theme/app_theme.dart';

class PdfTabWidget extends StatefulWidget {
  final VideoKitab? kitab;
  final bool isPremiumUser;
  final VoidCallback onOpenPdf;

  const PdfTabWidget({
    super.key,
    required this.kitab,
    required this.isPremiumUser,
    required this.onOpenPdf,
  });

  @override
  State<PdfTabWidget> createState() => _PdfTabWidgetState();
}

class _PdfTabWidgetState extends State<PdfTabWidget> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  bool _isLoading = true;
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    final hasPdf = widget.kitab?.pdfUrl?.isNotEmpty == true;

    if (!hasPdf) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                PhosphorIcons.filePdf(),
                size: 48,
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Tiada PDF tersedia untuk kitab ini',
                style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Show PDF viewer directly
    return Container(
      color: Colors.grey[100],
      child: Stack(
        children: [
          SfPdfViewer.network(
            widget.kitab!.pdfUrl!,
            key: _pdfViewerKey,
            canShowScrollHead: true,
            canShowScrollStatus: true,
            enableDoubleTapZooming: true,
            enableTextSelection: true,
            onDocumentLoaded: (details) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = false;
                });
              }
            },
            onDocumentLoadFailed: (details) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                });
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Gagal memuatkan PDF: ${details.error}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Memuatkan PDF...',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error state
          if (_hasError && !_isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                      size: 48,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal memuatkan PDF',
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sila cuba lagi',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
