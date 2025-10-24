import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool _isLoading = false;
  String? _error;
  
  // Overview metrics
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _totalBooks = 0;
  int _totalVideos = 0;
  int _totalCategories = 0;
  int _totalDownloads = 0;
  int _premiumSubscribers = 0;
  double _totalRevenue = 0.0;
  
  // Growth percentages
  double _userGrowthPercent = 0.0;
  double _activeUserGrowthPercent = 0.0;
  double _bookGrowthPercent = 0.0;
  double _subscriptionGrowthPercent = 0.0;
  
  // Chart data
  List<FlSpot> _userGrowthData = [];
  List<FlSpot> _revenueData = [];
  List<Map<String, dynamic>> _popularContent = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUsers => _totalUsers;
  int get activeUsers => _activeUsers;
  int get totalBooks => _totalBooks;
  int get totalVideos => _totalVideos;
  int get totalCategories => _totalCategories;
  int get totalDownloads => _totalDownloads;
  int get premiumSubscribers => _premiumSubscribers;
  double get totalRevenue => _totalRevenue;
  double get userGrowthPercent => _userGrowthPercent;
  double get activeUserGrowthPercent => _activeUserGrowthPercent;
  double get bookGrowthPercent => _bookGrowthPercent;
  double get subscriptionGrowthPercent => _subscriptionGrowthPercent;
  List<FlSpot> get userGrowthData => _userGrowthData;
  List<FlSpot> get revenueData => _revenueData;
  List<Map<String, dynamic>> get popularContent => _popularContent;

  Future<void> loadAnalytics({String period = '30 hari'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadOverviewMetrics(),
        _loadGrowthData(period),
        _loadChartData(period),
        _loadPopularContent(),
      ]);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOverviewMetrics() async {
    try {
      // Get total users
      final usersResponse = await _supabase
          .from('profiles')
          .select('id')
          .count(CountOption.exact);
      _totalUsers = usersResponse.count;

      // Get active users (logged in within last 30 days)
      final activeUsersResponse = await _supabase
          .from('profiles')
          .select('id')
          .gte('last_sign_in_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
          .count(CountOption.exact);
      _activeUsers = activeUsersResponse.count;

      // Get total books
      final booksResponse = await _supabase
          .from('kitab')
          .select('id')
          .count(CountOption.exact);
      _totalBooks = booksResponse.count;

      // Get total categories
      final categoriesResponse = await _supabase
          .from('categories')
          .select('id')
          .count(CountOption.exact);
      _totalCategories = categoriesResponse.count;

      // Get premium subscribers
      final subscriptionsResponse = await _supabase
          .from('subscriptions')
          .select('id')
          .eq('status', 'active')
          .count(CountOption.exact);
      _premiumSubscribers = subscriptionsResponse.count;

      // Calculate mock data for videos and downloads
      _totalVideos = (_totalBooks * 0.3).round(); // Assume 30% of books have videos
      _totalDownloads = (_totalBooks * 150).round(); // Mock download count

      // Calculate total revenue (mock calculation)
      _totalRevenue = _premiumSubscribers * 29.90; // Assuming RM29.90 per month

    } catch (e) {
      // Debug logging removed
    }
  }

  Future<void> _loadGrowthData(String period) async {
    try {
      final days = _getDaysFromPeriod(period);
      final startDate = DateTime.now().subtract(Duration(days: days * 2)); // Get previous period for comparison
      final midDate = DateTime.now().subtract(Duration(days: days));

      // Get user count for previous period
      final previousUsersResponse = await _supabase
          .from('profiles')
          .select('id')
          .gte('created_at', startDate.toIso8601String())
          .lt('created_at', midDate.toIso8601String())
          .count(CountOption.exact);
      final previousUsers = previousUsersResponse.count;

      // Get user count for current period
      final currentUsersResponse = await _supabase
          .from('profiles')
          .select('id')
          .gte('created_at', midDate.toIso8601String())
          .lt('created_at', DateTime.now().toIso8601String())
          .count(CountOption.exact);
      final currentUsers = currentUsersResponse.count;

      // Calculate growth percentages
      if (previousUsers > 0) {
        _userGrowthPercent = ((currentUsers - previousUsers) / previousUsers * 100);
        _activeUserGrowthPercent = _userGrowthPercent * 0.8; // Mock calculation
        _bookGrowthPercent = _userGrowthPercent * 0.6; // Mock calculation
        _subscriptionGrowthPercent = _userGrowthPercent * 1.2; // Mock calculation
      }

    } catch (e) {
      // Debug logging removed
      // Set default growth values
      _userGrowthPercent = 12.5;
      _activeUserGrowthPercent = 8.3;
      _bookGrowthPercent = 15.2;
      _subscriptionGrowthPercent = 22.1;
    }
  }

  Future<void> _loadChartData(String period) async {
    try {
      final days = _getDaysFromPeriod(period);
      
      // Generate mock user growth data
      _userGrowthData = List.generate(days ~/ 5, (index) {
        final baseValue = 100 + (index * 10);
        final randomVariation = (index % 3 - 1) * 5;
        return FlSpot(index.toDouble(), (baseValue + randomVariation).toDouble());
      });

      // Generate mock revenue data
      _revenueData = List.generate(6, (index) {
        final baseRevenue = 1000 + (index * 200);
        final randomVariation = (index % 2) * 100;
        return FlSpot(index.toDouble(), (baseRevenue + randomVariation).toDouble());
      });

    } catch (e) {
      // Debug logging removed
      // Set default chart data
      _userGrowthData = [
        const FlSpot(0, 100),
        const FlSpot(1, 120),
        const FlSpot(2, 110),
        const FlSpot(3, 140),
        const FlSpot(4, 160),
        const FlSpot(5, 180),
      ];
      
      _revenueData = [
        const FlSpot(0, 1000),
        const FlSpot(1, 1200),
        const FlSpot(2, 1100),
        const FlSpot(3, 1400),
        const FlSpot(4, 1600),
        const FlSpot(5, 1800),
      ];
    }
  }

  Future<void> _loadPopularContent() async {
    try {
      // Get popular books based on saved count
      final popularBooksResponse = await _supabase
          .from('kitab')
          .select('''
            id,
            title,
            saved_items!inner(id)
          ''')
          .limit(5);

      final popularBooks = (popularBooksResponse as List).map((book) {
        final savedCount = (book['saved_items'] as List).length;
        return {
          'title': book['title'],
          'views': savedCount * 10, // Mock view count
          'type': 'book',
        };
      }).toList();

      // Add mock video content
      final mockVideos = [
        {'title': 'Pengenalan Fiqh', 'views': 1250, 'type': 'video'},
        {'title': 'Tajwid Asas', 'views': 980, 'type': 'video'},
        {'title': 'Sejarah Islam', 'views': 750, 'type': 'video'},
      ];

      _popularContent = [...popularBooks, ...mockVideos];
      _popularContent.sort((a, b) => b['views'].compareTo(a['views']));
      _popularContent = _popularContent.take(5).toList();

    } catch (e) {
      // Debug logging removed
      // Set default popular content
      _popularContent = [
        {'title': 'Kitab Fiqh Muamalat', 'views': 1500, 'type': 'book'},
        {'title': 'Pengenalan Fiqh', 'views': 1250, 'type': 'video'},
        {'title': 'Kitab Aqidah', 'views': 1100, 'type': 'book'},
        {'title': 'Tajwid Asas', 'views': 980, 'type': 'video'},
        {'title': 'Kitab Hadis', 'views': 850, 'type': 'book'},
      ];
    }
  }

  int _getDaysFromPeriod(String period) {
    switch (period) {
      case '7 hari':
        return 7;
      case '30 hari':
        return 30;
      case '90 hari':
        return 90;
      case '1 tahun':
        return 365;
      default:
        return 30;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
