import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/saved_items_provider.dart';

class SaveVideoButton extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  final String? videoUrl;
  
  const SaveVideoButton({
    super.key,
    required this.videoId,
    required this.videoTitle,
    this.videoUrl,
  });

  @override
  State<SaveVideoButton> createState() => _SaveVideoButtonState();
}

class _SaveVideoButtonState extends State<SaveVideoButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SavedItemsProvider>(
      builder: (context, savedItemsProvider, child) {
        final isVideoSaved = savedItemsProvider.isVideoSaved(widget.videoId);
        
        return IconButton(
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              : Icon(
                  isVideoSaved ? Icons.download_done : Icons.download_outlined,
                  color: AppTheme.primaryColor,
                ),
          onPressed: _isLoading ? null : () => _toggleSaveVideo(savedItemsProvider, isVideoSaved),
          tooltip: isVideoSaved ? 'Buang dari Simpanan' : 'Simpan Video',
        );
      },
    );
  }

  Future<void> _toggleSaveVideo(SavedItemsProvider provider, bool isCurrentlySaved) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool success;
      String message;

      if (isCurrentlySaved) {
        // Remove from saved
        success = await provider.removeVideoFromSaved(widget.videoId);
        message = success ? 'Video telah dibuang dari simpanan' : 'Gagal membuang video dari simpanan';
      } else {
        // Add to saved
        success = await provider.addVideoToSaved(
          widget.videoId,
          widget.videoTitle,
          widget.videoUrl,
        );
        message = success ? 'Video telah disimpan' : 'Gagal menyimpan video';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  success
                      ? (isCurrentlySaved ? Icons.download_done : Icons.download)
                      : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: success
                ? (isCurrentlySaved ? Colors.orange : AppTheme.primaryColor)
                : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
