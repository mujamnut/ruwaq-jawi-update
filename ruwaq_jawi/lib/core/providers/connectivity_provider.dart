import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider with ChangeNotifier {
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  List<ConnectivityResult> get connectionStatus => _connectionStatus;
  ConnectivityResult get primaryConnectionStatus => _connectionStatus.isNotEmpty ? _connectionStatus.first : ConnectivityResult.none;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  
  String get connectionType {
    final primary = primaryConnectionStatus;
    switch (primary) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.other:
        return 'Other';
      case ConnectivityResult.none:
        return 'No Connection';
    }
  }

  ConnectivityProvider() {
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    try {
      // Get initial connectivity status
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
      
      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _updateConnectionStatus,
        onError: (error) {
          debugPrint('Connectivity error: $error');
          _updateConnectionStatus([ConnectivityResult.none]);
        },
      );
    } catch (e) {
      debugPrint('Failed to initialize connectivity: $e');
      _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    _connectionStatus = result;
    final wasOnline = _isOnline;
    _isOnline = result.isNotEmpty && !result.every((status) => status == ConnectivityResult.none);
    
    debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'} ($_connectionType)');
    
    // Only notify if status actually changed
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  String get _connectionType => connectionType;

  /// Check if device has internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result.isNotEmpty && !result.every((status) => status == ConnectivityResult.none);
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Retry connection check
  Future<void> refreshConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      debugPrint('Error refreshing connectivity: $e');
      _updateConnectionStatus([ConnectivityResult.none]);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
