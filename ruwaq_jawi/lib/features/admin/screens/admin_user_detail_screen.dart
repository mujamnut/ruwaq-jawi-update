import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/subscription.dart';
import '../../../core/models/bookmark.dart';
import '../../../core/models/reading_progress.dart';
import '../../../core/models/saved_item.dart';
import '../../../core/theme/app_theme.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({
    super.key,
    required this.userId,
  });

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
  UserProfile? _user;
  Subscription? _subscription;
  List<Bookmark> _bookmarks = [];
  List<ReadingProgress> _readingProgress = [];
  List<SavedItem> _savedItems = [];
  
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load user profile with real email from auth.users
      Map<String, dynamic> userResponse;
      try {
        final userList = await SupabaseService.client.rpc('get_all_profiles_with_email') as List;
        userResponse = userList.firstWhere(
          (user) => user['id'] == widget.userId,
          orElse: () => throw Exception('User not found'),
        );
      } catch (e) {
        // Fallback to normal profiles query if RPC fails
        print('RPC failed for user detail, using fallback: $e');
        userResponse = await SupabaseService.from('profiles')
            .select()
            .eq('id', widget.userId)
            .single();
        
        // Add dummy email as fallback
        userResponse['email'] = '${userResponse['full_name']?.toString().toLowerCase().replaceAll(' ', '')}@domain.com';
      }

      final user = UserProfile.fromJson(userResponse);

      // Load active subscription
      Subscription? subscription;
      try {
        final subscriptionResponse = await SupabaseService.from('subscriptions')
            .select()
            .eq('user_id', widget.userId)
            .eq('status', 'active')
            .gt('current_period_end', DateTime.now().toIso8601String())
            .maybeSingle();

        if (subscriptionResponse != null) {
          subscription = Subscription.fromJson(subscriptionResponse);
        }
      } catch (e) {
        // Subscription might not exist
        subscription = null;
      }

      // Load user activity data
      final bookmarksData = await SupabaseService.from('bookmarks')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      final readingProgressData = await SupabaseService.from('reading_progress')
          .select()
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false);

      final savedItemsData = await SupabaseService.from('saved_items')
          .select()
          .eq('user_id', widget.userId)
          .order('created_at', ascending: false);

      setState(() {
        _user = user;
        _subscription = subscription;
        _bookmarks = (bookmarksData as List)
            .map((json) => Bookmark.fromJson(json))
            .toList();
        _readingProgress = (readingProgressData as List)
            .map((json) => ReadingProgress.fromJson(json))
            .toList();
        _savedItems = (savedItemsData as List)
            .map((json) => SavedItem.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan data pengguna: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_user?.fullName ?? 'Detail Pengguna'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Muat Semula',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memuatkan data pengguna...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Ralat',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUserData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: AppTheme.textLightColor,
              ),
              child: const Text('Cuba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_user == null) {
      return const Center(
        child: Text('Pengguna tidak dijumpai'),
      );
    }

    return Column(
      children: [
        _buildUserHeader(),
        _buildTabBar(),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: _user!.isAdmin
                ? Colors.purple.withOpacity(0.1)
                : AppTheme.primaryColor.withOpacity(0.1),
            child: _user!.avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      _user!.avatarUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _user!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                        size: 50,
                        color: _user!.isAdmin ? Colors.purple : AppTheme.primaryColor,
                      ),
                    ),
                  )
                : Icon(
                    _user!.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    size: 50,
                    color: _user!.isAdmin ? Colors.purple : AppTheme.primaryColor,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            _user!.fullName ?? 'Tiada Nama',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user!.role.toUpperCase(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Bookmark', _bookmarks.length.toString()),
              _buildStatItem('Membaca', _readingProgress.length.toString()),
              _buildStatItem('Disimpan', _savedItems.length.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textSecondaryColor,
        indicatorColor: AppTheme.primaryColor,
        tabs: const [
          Tab(text: 'Info', icon: Icon(Icons.info_outline)),
          Tab(text: 'Bookmark', icon: Icon(Icons.bookmark_outline)),
          Tab(text: 'Membaca', icon: Icon(Icons.menu_book_outlined)),
          Tab(text: 'Disimpan', icon: Icon(Icons.favorite_outline)),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildInfoTab(),
        _buildBookmarksTab(),
        _buildReadingProgressTab(),
        _buildSavedItemsTab(),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            'Maklumat Asas',
            [
              _buildDetailRow('ID Pengguna', _user!.id),
              _buildDetailRow('Nama Penuh', _user!.fullName ?? 'Tiada'),
              _buildDetailRow('Email', _user!.email ?? 'Tiada'),
              _buildDetailRow('Peranan', _user!.role.toUpperCase()),
              _buildDetailRow('Telefon', _user!.phoneNumber ?? 'Tiada'),
              _buildDetailRow('Tarikh Daftar', _formatFullDate(_user!.createdAt)),
              _buildDetailRow('Kemaskini Terakhir', _formatFullDate(_user!.updatedAt)),
            ],
          ),
          
          if (_subscription != null) ...[
            const SizedBox(height: 24),
            _buildSection(
              'Maklumat Langganan',
              [
                _buildDetailRow('Pelan', _subscription!.planDisplayName),
                _buildDetailRow('Status', _subscription!.status.toUpperCase()),
                _buildDetailRow('Tarikh Mula', _formatFullDate(_subscription!.startDate)),
                _buildDetailRow('Tarikh Tamat', _formatFullDate(_subscription!.endDate)),
                _buildDetailRow('Hari Berbaki', '${_subscription!.daysRemaining} hari'),
                _buildDetailRow('Jumlah', _subscription!.formattedAmount),
                _buildDetailRow('Pembaharuan Auto', _subscription!.autoRenew ? 'Ya' : 'Tidak'),
                _buildDetailRow('Kaedah Bayar', _subscription!.paymentMethod ?? 'Tiada'),
              ],
            ),
          ] else ...[
            const SizedBox(height: 24),
            _buildSection(
              'Maklumat Langganan',
              [
                _buildDetailRow('Status', 'TIADA LANGGANAN AKTIF'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookmarksTab() {
    if (_bookmarks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada bookmark'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.bookmark, color: AppTheme.primaryColor),
            title: Text(bookmark.title),
            subtitle: Text(bookmark.contentType == 'pdf' 
                ? 'Halaman ${bookmark.pdfPage}'
                : 'Video ${bookmark.videoPosition}s'),
            trailing: Text(_formatDate(bookmark.createdAt)),
          ),
        );
      },
    );
  }

  Widget _buildReadingProgressTab() {
    if (_readingProgress.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada aktiviti membaca'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _readingProgress.length,
      itemBuilder: (context, index) {
        final progress = _readingProgress[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircularProgressIndicator(
              value: progress.completionPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            title: Text('Kitab ID: ${progress.kitabId}'),
            subtitle: Text('${progress.completionPercentage.toInt()}% selesai'),
            trailing: Text(_formatDate(progress.updatedAt)),
          ),
        );
      },
    );
  }

  Widget _buildSavedItemsTab() {
    if (_savedItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada item disimpan'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedItems.length,
      itemBuilder: (context, index) {
        final savedItem = _savedItems[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.favorite, color: Colors.red),
            title: Text(savedItem.videoTitle ?? savedItem.folderName),
            subtitle: Text(savedItem.itemType.toUpperCase()),
            trailing: Text(_formatDate(savedItem.createdAt)),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minit lagu';
    } else {
      return 'Baru sahaja';
    }
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
