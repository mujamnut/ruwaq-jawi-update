import 'package:flutter/material.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/subscription.dart';
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
  List<Map<String, dynamic>> _ebookInteractions = [];
  List<Map<String, dynamic>> _videoKitabInteractions = [];
  int _totalBookmarks = 0;
  
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final profile = await SupabaseService.from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      _loadUserData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Akses ditolak. Anda tidak mempunyai kebenaran admin.';
          _isLoading = false;
        });
      }
    }
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
        final subscriptionResponse = await SupabaseService.from('user_subscriptions')
            .select('*, subscription_plans!inner(name, price, duration_days)')
            .eq('user_id', widget.userId)
            .eq('status', 'active')
            .gt('end_date', DateTime.now().toUtc().toIso8601String())
            .maybeSingle();

        if (subscriptionResponse != null) {
          subscription = Subscription.fromJson(subscriptionResponse);
        }
      } catch (e) {
        // Subscription might not exist
        subscription = null;
      }

      // Load user activity data from real tables
      final ebookInteractionsData = await SupabaseService.from('ebook_user_interactions')
          .select('''
            id, is_saved, is_downloaded, created_at, updated_at,
            ebooks!ebook_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false);

      final videoKitabInteractionsData = await SupabaseService.from('video_kitab_user_interactions')
          .select('''
            id, is_saved, created_at, updated_at,
            video_kitab!video_kitab_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false);

      // Count total bookmarks - currently not available in basic table structure
      int totalBookmarks = 0;

      setState(() {
        _user = user;
        _subscription = subscription;
        _ebookInteractions = List<Map<String, dynamic>>.from(ebookInteractionsData);
        _videoKitabInteractions = List<Map<String, dynamic>>.from(videoKitabInteractionsData);
        _totalBookmarks = totalBookmarks;
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
              _buildStatItem('Bookmark', _totalBookmarks.toString()),
              _buildStatItem('E-books', _ebookInteractions.length.toString()),
              _buildStatItem('Video Kitab', _videoKitabInteractions.length.toString()),
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
          Tab(text: 'E-books', icon: Icon(Icons.book_outlined)),
          Tab(text: 'Video Kitab', icon: Icon(Icons.video_library_outlined)),
          Tab(text: 'Aktiviti', icon: Icon(Icons.timeline_outlined)),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildInfoTab(),
        _buildEbooksTab(),
        _buildVideoKitabTab(),
        _buildActivityTab(),
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

  Widget _buildEbooksTab() {
    if (_ebookInteractions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada interaksi e-book'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ebookInteractions.length,
      itemBuilder: (context, index) {
        final interaction = _ebookInteractions[index];
        final ebook = interaction['ebooks'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircularProgressIndicator(
              value: (interaction['progress_percentage'] ?? 0) / 100.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            title: Text(ebook?['title'] ?? 'E-book Tanpa Judul'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Oleh: ${ebook?['author'] ?? 'Penulis'}'),
                Text('Halaman ${interaction['current_page'] ?? 1}'),
                Text('${(interaction['progress_percentage'] ?? 0).toInt()}% selesai'),
              ],
            ),
            trailing: Text(_formatDate(DateTime.parse(interaction['updated_at']))),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildVideoKitabTab() {
    if (_videoKitabInteractions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada interaksi video kitab'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videoKitabInteractions.length,
      itemBuilder: (context, index) {
        final interaction = _videoKitabInteractions[index];
        final videoKitab = interaction['video_kitab'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircularProgressIndicator(
              value: (interaction['overall_progress_percentage'] ?? 0) / 100.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            title: Text(videoKitab?['title'] ?? 'Video Kitab Tanpa Judul'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Oleh: ${videoKitab?['author'] ?? 'Penulis'}'),
                Text('Halaman ${interaction['current_page'] ?? 1}'),
                Text('${(interaction['overall_progress_percentage'] ?? 0).toInt()}% selesai'),
              ],
            ),
            trailing: Text(_formatDate(DateTime.parse(interaction['updated_at']))),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildActivityTab() {
    final allInteractions = <Map<String, dynamic>>[];
    
    // Combine all interactions for activity timeline
    for (var ebook in _ebookInteractions) {
      allInteractions.add({
        ...ebook,
        'type': 'ebook',
        'title': ebook['ebooks']?['title'] ?? 'E-book Tanpa Judul',
      });
    }
    
    for (var video in _videoKitabInteractions) {
      allInteractions.add({
        ...video,
        'type': 'video_kitab',
        'title': video['video_kitab']?['title'] ?? 'Video Kitab Tanpa Judul',
      });
    }
    
    // Sort by last accessed
    allInteractions.sort((a, b) => 
        DateTime.parse(b['updated_at']).compareTo(DateTime.parse(a['updated_at'])));

    if (allInteractions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tiada aktiviti'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allInteractions.length,
      itemBuilder: (context, index) {
        final activity = allInteractions[index];
        final isEbook = activity['type'] == 'ebook';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isEbook ? Icons.book : Icons.video_library,
              color: AppTheme.primaryColor,
            ),
            title: Text(activity['title']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEbook ? 'E-book' : 'Video Kitab'),
                if (activity['is_saved'] == true)
                  Text('💾 Disimpan', style: TextStyle(color: AppTheme.primaryColor)),
                if (activity['user_notes'] != null && activity['user_notes'].toString().isNotEmpty)
                  Text('📝 Ada catatan'),
              ],
            ),
            trailing: Text(_formatDate(DateTime.parse(activity['updated_at']))),
            isThreeLine: true,
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
