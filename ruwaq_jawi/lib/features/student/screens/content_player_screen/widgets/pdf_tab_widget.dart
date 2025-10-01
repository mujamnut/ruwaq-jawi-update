import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../../core/models/video_kitab.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/services/pdf_cache_service.dart';

class PdfTabWidget extends StatelessWidget {
  final VideoKitab? kitab;
  final PdfViewerController? pdfController;
  final int currentPdfPage;
  final int totalPdfPages;
  final String? cachedPdfPath;
  final bool isPdfDownloading;
  final double downloadProgress;
  final VoidCallback onDownloadPdf;
  final Function(String) onSetCachedPath;
  final Function(int) onPageChanged;
  final Function(int) onDocumentLoaded;

  const PdfTabWidget({
    super.key,
    required this.kitab,
    required this.pdfController,
    required this.currentPdfPage,
    required this.totalPdfPages,
    required this.cachedPdfPath,
    required this.isPdfDownloading,
    required this.downloadProgress,
    required this.onDownloadPdf,
    required this.onSetCachedPath,
    required this.onPageChanged,
    required this.onDocumentLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Modern PDF toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(bottom: BorderSide(color: AppTheme.borderColor)),
          ),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.filePdf(),
                size: 18,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman $currentPdfPage${totalPdfPages > 0 ? ' / $totalPdfPages' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
              const Spacer(),
              // Cache status indicator
              if (cachedPdfPath != null && cachedPdfPath != 'ONLINE_VIEW') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.downloadSimple(),
                        size: 12,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (cachedPdfPath == 'ONLINE_VIEW') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.globe(),
                        size: 12,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.magnifyingGlassMinus(),
                      size: 18,
                    ),
                    onPressed: () => pdfController?.zoomLevel = 1.0,
                    tooltip: 'Zum Keluar',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: PhosphorIcon(
                      PhosphorIcons.magnifyingGlassPlus(),
                      size: 18,
                    ),
                    onPressed: () => pdfController?.zoomLevel = 2.0,
                    tooltip: 'Zum Masuk',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // PDF Viewer with caching support
        Expanded(child: _buildPdfViewer(context)),

        // Modern PDF navigation controls
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: AppTheme.borderColor)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPdfNavButton(
                context: context,
                icon: PhosphorIcons.skipBack(),
                onPressed: currentPdfPage > 1 ? () => pdfController?.firstPage() : null,
                tooltip: 'Halaman Pertama',
              ),
              _buildPdfNavButton(
                context: context,
                icon: PhosphorIcons.caretLeft(),
                onPressed: currentPdfPage > 1 ? () => pdfController?.previousPage() : null,
                tooltip: 'Halaman Sebelum',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currentPdfPage',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildPdfNavButton(
                context: context,
                icon: PhosphorIcons.caretRight(),
                onPressed: currentPdfPage < totalPdfPages ? () => pdfController?.nextPage() : null,
                tooltip: 'Halaman Seterusnya',
              ),
              _buildPdfNavButton(
                context: context,
                icon: PhosphorIcons.skipForward(),
                onPressed: currentPdfPage < totalPdfPages ? () => pdfController?.lastPage() : null,
                tooltip: 'Halaman Terakhir',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPdfNavButton({
    required BuildContext context,
    required PhosphorIconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return IconButton(
      icon: PhosphorIcon(
        icon,
        size: 20,
        color: onPressed != null
            ? AppTheme.textPrimaryColor
            : AppTheme.textSecondaryColor,
      ),
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildPdfViewer(BuildContext context) {
    // No PDF URL available
    if (kitab?.pdfUrl == null || kitab!.pdfUrl!.isEmpty) {
      return _buildNoPdfMessage(context);
    }

    // PDF is downloading
    if (isPdfDownloading) {
      return _buildDownloadingMessage(context);
    }

    // Use cached PDF if available, or force online view
    if (cachedPdfPath != null) {
      if (cachedPdfPath == 'ONLINE_VIEW') {
        // Force online view
        return SfPdfViewer.network(
          kitab!.pdfUrl!,
          controller: pdfController,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (PdfPageChangedDetails details) {
            onPageChanged(details.newPageNumber);
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            onDocumentLoaded(details.document.pages.count);
          },
        );
      } else {
        // Use cached file
        return SfPdfViewer.file(
          File(cachedPdfPath!),
          controller: pdfController,
          enableDoubleTapZooming: true,
          enableTextSelection: true,
          canShowScrollHead: true,
          canShowScrollStatus: true,
          onPageChanged: (PdfPageChangedDetails details) {
            onPageChanged(details.newPageNumber);
          },
          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
            onDocumentLoaded(details.document.pages.count);
          },
        );
      }
    }

    // Check if PDF is cached, if not show download prompt
    final isCached = PdfCacheService.isPdfCached(kitab!.pdfUrl!);
    if (!isCached) {
      return _buildDownloadPrompt(context);
    }

    // Fallback to network PDF viewer
    return SfPdfViewer.network(
      kitab!.pdfUrl!,
      controller: pdfController,
      enableDoubleTapZooming: true,
      enableTextSelection: true,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      onPageChanged: (PdfPageChangedDetails details) {
        onPageChanged(details.newPageNumber);
      },
      onDocumentLoaded: (PdfDocumentLoadedDetails details) {
        onDocumentLoaded(details.document.pages.count);
        // Auto-download PDF for caching
        onDownloadPdf();
      },
    );
  }

  Widget _buildNoPdfMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: PhosphorIcon(
                PhosphorIcons.filePdf(),
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'E-Book Tidak Tersedia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kitab ini tidak mempunyai e-book yang tersedia untuk dibaca.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingMessage(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: PhosphorIcon(
                PhosphorIcons.cloudArrowDown(),
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Memuat turun E-Book...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: (downloadProgress * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 100 - (downloadProgress * 100).round(),
                    child: const SizedBox(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(downloadProgress * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: PhosphorIcon(
                PhosphorIcons.cloudArrowDown(),
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Muat turun untuk akses offline',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Muat turun PDF ini untuk akses pantas tanpa internet pada masa akan datang',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onDownloadPdf,
              icon: PhosphorIcon(
                PhosphorIcons.downloadSimple(),
                color: Colors.white,
                size: 18,
              ),
              label: const Text('Muat Turun PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                // Set a flag to show network viewer
                onSetCachedPath('ONLINE_VIEW'); // Special flag
              },
              icon: PhosphorIcon(
                PhosphorIcons.globe(),
                color: AppTheme.textSecondaryColor,
                size: 16,
              ),
              label: Text(
                'Lihat online sahaja',
                style: TextStyle(color: AppTheme.textSecondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}