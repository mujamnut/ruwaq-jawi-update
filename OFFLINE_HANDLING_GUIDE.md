# 📡 Centralized Offline Handling Guide

## Overview
Maktabah Ruwaq Jawi sekarang ada **centralized offline handling system** yang menyeluruh untuk seluruh app!

## 🎯 Komponen Utama

### 1. **ConnectivityProvider** (`core/providers/connectivity_provider.dart`)
Global provider yang monitor internet connectivity status untuk seluruh app.

**Features:**
- ✅ Auto-detect connectivity changes
- ✅ Notify listeners bila status berubah
- ✅ Helper methods untuk common operations

**Usage:**
```dart
// Check connectivity status
final connectivity = context.read<ConnectivityProvider>();
if (connectivity.isOffline) {
  // Handle offline
}

// Wait for connection
await connectivity.waitForConnection(timeout: Duration(seconds: 5));

// Execute when online
await connectivity.executeWhenOnline(() async {
  return await fetchData();
});

// Callback when connection restored
connectivity.onConnectionRestored(() {
  print('Back online!');
});
```

### 2. **NetworkService** (`core/services/network_service.dart`)
Centralized service untuk handle semua network operations dengan automatic retry.

**Features:**
- ✅ Automatic offline detection
- ✅ Show offline dialog automatically
- ✅ Retry mechanism dengan exponential backoff
- ✅ Network error detection

**Usage:**
```dart
// Simple internet requirement check
final hasInternet = await NetworkService.requiresInternet(
  context,
  message: 'Custom offline message',
);

if (!hasInternet) return;

// Execute with auto retry
final result = await NetworkService.executeWithRetry(
  context: context,
  operation: () async {
    return await fetchDataFromAPI();
  },
  maxRetries: 3,
  retryDelay: Duration(seconds: 2),
);

// Execute with connectivity check
final data = await NetworkService.executeWithConnectivity(
  context: context,
  operation: () async {
    return await loadVideo();
  },
  showOfflineDialog: true,
);
```

### 3. **Network-Aware Widgets** (`core/widgets/network_aware_builder.dart`)
Smart widgets yang rebuild based on connectivity status.

**Available Widgets:**

#### a) NetworkAwareBuilder
```dart
NetworkAwareBuilder(
  online: (context) => OnlineContent(),
  offline: (context) => OfflineContent(),
)
```

#### b) OnlineOnly
```dart
OnlineOnly(
  child: VideoPlayer(),
  offlinePlaceholder: OfflineMessage(),
)
```

#### c) OfflineOnly
```dart
OfflineOnly(
  child: Text('You are offline'),
)
```

#### d) NetworkRequiredWidget
```dart
NetworkRequiredWidget(
  child: VideoList(),
  loadingWidget: LoadingSpinner(),
  offlineMessage: 'Videos require internet',
  onRetry: () => refreshVideos(),
)
```

#### e) ConnectionStatusIndicator
```dart
ConnectionStatusIndicator(
  showWhenOnline: true, // Show indicator even when online
)
```

### 4. **OfflineBanner** (`core/widgets/offline_banner.dart`)
Global banner yang show di top bila offline - **dah active untuk seluruh app!**

Located: Wrapped around entire app dalam `main.dart`

## 🚀 Cara Guna

### For Video Features
```dart
void playVideo() async {
  // Check internet first
  final hasInternet = await NetworkService.requiresInternet(
    context,
    message: 'Video memerlukan sambungan internet',
  );

  if (!hasInternet) return;

  // Proceed with video
  _playVideo();
}
```

### For Data Fetching
```dart
Future<List<Data>> fetchData() async {
  return await NetworkService.executeWithRetry(
    context: context,
    operation: () async {
      return await api.getData();
    },
    maxRetries: 3,
  );
}
```

### For UI Components
```dart
Widget build(BuildContext context) {
  return NetworkAwareBuilder(
    online: (context) => DataList(data),
    offline: (context) => OfflineMessage(),
  );
}
```

## ✨ Benefits

1. **Single Source of Truth**
   - Satu provider untuk semua connectivity checks
   - Consistent behavior across app

2. **Automatic Handling**
   - Auto-detect offline/online
   - Auto-show dialogs dan messages
   - Auto-retry failed operations

3. **Better UX**
   - Smooth transitions
   - Clear offline indicators
   - Helpful error messages

4. **Less Code Duplication**
   - Reusable components
   - Consistent patterns
   - Easier maintenance

## 📦 Updated Files

### New Files Created:
1. `core/services/network_service.dart` - Centralized network handling
2. `core/widgets/network_aware_builder.dart` - Smart network widgets

### Enhanced Files:
3. `core/providers/connectivity_provider.dart` - Added helper methods
4. `features/student/screens/kitab_detail_screen.dart` - Uses NetworkService
5. `features/admin/screens/admin_youtube_auto_form_screen.dart` - Uses provider

### Already Existing (No changes needed):
- `core/widgets/offline_banner.dart` - Global banner (already active)
- `core/widgets/offline_state_screen.dart` - Full screen offline
- `main.dart` - ConnectivityProvider already registered

## 🎓 Migration Guide

### Old Way (scattered):
```dart
// ❌ Old - Manual check everywhere
final result = await Connectivity().checkConnectivity();
if (result.contains(ConnectivityResult.none)) {
  showDialog(...);
  return;
}
```

### New Way (centralized):
```dart
// ✅ New - Use NetworkService
final hasInternet = await NetworkService.requiresInternet(context);
if (!hasInternet) return;
```

## 📝 Examples

### Example 1: Video Player with Offline Handling
```dart
class VideoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return NetworkRequiredWidget(
      child: VideoPlayer(videoUrl),
      offlineMessage: 'Video memerlukan internet untuk dimainkan',
      onRetry: () => refreshVideo(),
    );
  }
}
```

### Example 2: API Call with Auto Retry
```dart
Future<void> loadContent() async {
  final data = await NetworkService.executeWithRetry(
    context: context,
    operation: () => api.getContent(),
    maxRetries: 3,
    retryDelay: Duration(seconds: 2),
  );

  if (data != null) {
    setState(() => content = data);
  }
}
```

### Example 3: Conditional UI Based on Connectivity
```dart
Widget build(BuildContext context) {
  return NetworkAwareBuilder(
    online: (context) => StreamingContent(),
    offline: (context) => DownloadedContent(),
  );
}
```

## 🔧 Best Practices

1. **Always use NetworkService** untuk operations yang require internet
2. **Use NetworkAwareBuilder** untuk UI yang bergantung pada connectivity
3. **Provider already setup** - just use `context.read<ConnectivityProvider>()`
4. **OfflineBanner always shows** - no need manual implementation
5. **Let system handle dialogs** - automatic offline dialogs

## 🎉 Result

Sekarang **satu centralized system** handle semua offline scenarios untuk seluruh app:
- ✅ Consistent UX across all screens
- ✅ Automatic detection & handling
- ✅ Less code, cleaner architecture
- ✅ Better user experience
- ✅ Easier to maintain & extend
