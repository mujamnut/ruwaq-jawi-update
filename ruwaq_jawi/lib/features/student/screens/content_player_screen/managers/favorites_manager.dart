import 'package:flutter/material.dart';
import '../../../../../core/models/video_episode.dart';
import '../../../../../core/services/local_favorites_service.dart';

class FavoritesManager {
  bool _isSaved = false;
  bool _isSaveLoading = false;

  final VoidCallback? onStateChanged;

  FavoritesManager({this.onStateChanged});

  // Getters
  bool get isSaved => _isSaved;
  bool get isSaveLoading => _isSaveLoading;

  void checkSaveStatus(VideoEpisode? currentEpisode, String? kitabId) {
    if (currentEpisode != null) {
      _isSaved = LocalFavoritesService.isVideoEpisodeFavorite(
        currentEpisode.id,
      );
      onStateChanged?.call();
    }
  }

  Future<bool> toggleSaved(VideoEpisode? currentEpisode, String? kitabId) async {
    if (currentEpisode == null || _isSaveLoading) return false;

    _isSaveLoading = true;
    onStateChanged?.call();

    try {
      bool success;
      if (_isSaved) {
        success = await LocalFavoritesService.removeVideoEpisodeFromFavorites(
          currentEpisode.id,
        );
      } else {
        success = await LocalFavoritesService.addVideoEpisodeToFavorites(
          currentEpisode.id,
        );
      }

      if (success) {
        _isSaved = !_isSaved;
        _isSaveLoading = false;
        onStateChanged?.call();
        return true;
      }

      _isSaveLoading = false;
      onStateChanged?.call();
      return false;
    } catch (e) {
      _isSaveLoading = false;
      onStateChanged?.call();
      rethrow;
    }
  }
}