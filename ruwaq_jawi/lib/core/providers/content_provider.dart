import 'package:flutter/foundation.dart';
import '../services/content_service.dart';

class ContentProvider with ChangeNotifier {
  final ContentService _contentService;
  bool _isLoading = false;
  String? _error;
  bool _hasPremiumAccess = false;
  Map<String, dynamic>? _subscriptionDetails;
  List<Map<String, dynamic>> _kitabList = [];

  ContentProvider(this._contentService);

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPremiumAccess => _hasPremiumAccess;
  List<Map<String, dynamic>> get kitabList => _kitabList;
  Map<String, dynamic>? get subscriptionDetails => _subscriptionDetails;

  Future<void> checkPremiumAccess() async {
    try {
      _isLoading = true;
      notifyListeners();

      _hasPremiumAccess = await _contentService.canAccessPremiumContent();
      _subscriptionDetails = await _contentService.getSubscriptionDetails();

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadKitabList() async {
    try {
      _isLoading = true;
      notifyListeners();

      _kitabList = await _contentService.getAccessibleKitab();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getKitabDetails(String kitabId) async {
    try {
      _isLoading = true;
      notifyListeners();

      return await _contentService.getKitabDetails(kitabId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
