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

  /// Execute a callback when connection is restored
  ///
  /// Usage:
  /// ```dart
  /// connectivity.onConnectionRestored(() {
  ///   // Retry failed operations
  /// });
  /// ```
  void onConnectionRestored(VoidCallback callback) {
    if (_isOnline) {
      callback();
      return;
    }

    late VoidCallback listener;
    listener = () {
      if (_isOnline) {
        callback();
        removeListener(listener);
      }
    };
    addListener(listener);
  }

  /// Wait for connection to be available
  ///
  /// Returns immediately if already online
  /// Otherwise waits until connection is restored or timeout
  Future<bool> waitForConnection({Duration? timeout}) async {
    if (_isOnline) return true;

    final completer = Completer<bool>();
    late VoidCallback listener;

    listener = () {
      if (_isOnline && !completer.isCompleted) {
        completer.complete(true);
        removeListener(listener);
      }
    };

    addListener(listener);

    try {
      if (timeout != null) {
        return await completer.future.timeout(
          timeout,
          onTimeout: () {
            removeListener(listener);
            return false;
          },
        );
      }
      return await completer.future;
    } catch (e) {
      removeListener(listener);
      return false;
    }
  }

  /// Execute an operation only when online
  ///
  /// Returns null if offline, otherwise returns operation result
  Future<T?> executeWhenOnline<T>(Future<T> Function() operation) async {
    if (isOffline) {
      debugPrint('⚠️ Cannot execute operation: Device is offline');
      return null;
    }

    try {
      return await operation();
    } catch (e) {
      debugPrint('❌ Operation failed: $e');
      // Refresh connectivity in case we went offline
      await refreshConnectivity();
      rethrow;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
