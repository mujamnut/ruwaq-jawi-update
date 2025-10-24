import 'package:flutter/material.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/models/subscription.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hugeicons/hugeicons.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

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
  // Pagination & scroll controllers
  final ScrollController _ebookScrollController = ScrollController();
  final ScrollController _videoScrollController = ScrollController();
  int _ebookPage = 0;
  int _videoPage = 0;
  final int _pageSize = 20;
  bool _ebooksHasMore = true;
  bool _videosHasMore = true;
  bool _loadingMoreEbooks = false;
  bool _loadingMoreVideos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _ebookScrollController.addListener(_onEbookScroll);
    _videoScrollController.addListener(_onVideoScroll);
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
      final profile = await SupabaseService.from(
        'profiles',
      ).select('role').eq('id', user.id).maybeSingle();

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
    _ebookScrollController.dispose();
    _videoScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load user profile with email (prefer targeted RPC if available)
      Map<String, dynamic> userResponse;
      try {
        final result = await SupabaseService.client.rpc(
          'get_profile_with_email',
          params: {'p_user_id': widget.userId},
        );
        if (result is Map) {
          userResponse = Map<String, dynamic>.from(result);
        } else if (result is List && result.isNotEmpty) {
          userResponse = Map<String, dynamic>.from(result.first);
        } else {
          throw Exception('Empty response from get_profile_with_email');
        }
      } catch (_) {
        try {
          final userList = await SupabaseService.client
              .rpc('get_all_profiles_with_email') as List;
          userResponse = userList.firstWhere(
            (user) => user['id'] == widget.userId,
            orElse: () => throw Exception('User not found'),
          );
        } catch (e2) {
          // Fallback to normal profiles query if RPCs fail
          userResponse = await SupabaseService.from(
            'profiles',
          ).select().eq('id', widget.userId).single();
          // Add dummy email as fallback
          userResponse['email'] =
              '${userResponse['full_name']?.toString().toLowerCase().replaceAll(' ', '')}@domain.com';
        }
      }

      final user = UserProfile.fromJson(userResponse);

      // Load active subscription
      Subscription? subscription;
      try {
        final subscriptionResponse =
            await SupabaseService.from('user_subscriptions')
                .select(
                  '*, subscription_plans!inner(name, price, duration_days)',
                )
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

      // Load first page of user activity data (paginated)
      final ebookInteractionsData = await SupabaseService.from(
        'ebook_user_interactions',
      )
          .select('''
            id, is_saved, is_downloaded, created_at, updated_at,
            ebooks!ebook_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(0, _pageSize - 1);

      final videoKitabInteractionsData = await SupabaseService.from(
        'video_kitab_user_interactions',
      )
          .select('''
            id, is_saved, created_at, updated_at,
            video_kitab!video_kitab_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(0, _pageSize - 1);

      // Count total bookmarks - currently not available in basic table structure
      int totalBookmarks = 0;

      setState(() {
        _user = user;
        _subscription = subscription;
        _ebookPage = 1;
        _videoPage = 1;
        _ebooksHasMore = (ebookInteractionsData as List).length == _pageSize;
        _videosHasMore = (videoKitabInteractionsData as List).length == _pageSize;
        _ebookInteractions =
            List<Map<String, dynamic>>.from(ebookInteractionsData);
        _videoKitabInteractions =
            List<Map<String, dynamic>>.from(videoKitabInteractionsData);
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
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: AppTheme.textPrimaryColor,
            size: 22,
          ),
          tooltip: 'Kembali',
        ),
        actions: [
          if (_user?.email != null && _user!.email!.isNotEmpty)
            IconButton(
              tooltip: 'Salin Emel',
              icon: const Icon(Icons.mail_outline),
              onPressed: () => _copyToClipboard(_user!.email!, 'Emel'),
            ),
          IconButton(
            tooltip: 'Salin ID Pengguna',
            icon: const Icon(Icons.copy),
            onPressed: () => _copyToClipboard(_user?.id ?? widget.userId, 'ID Pengguna'),
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'reset_password', child: Text('Hantar Reset Password')),
              PopupMenuItem(value: 'resend_verification', child: Text('Hantar Verifikasi Emel')),
              PopupMenuItem(value: 'ban_user', child: Text('Ban pengguna (sementara)')),
            ],
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
      return const Center(child: Text('Pengguna tidak dijumpai'));
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(child: _buildUserHeader()),
        SliverAppBar(
          pinned: true,
          floating: false,
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondaryColor,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Info', icon: Icon(HugeIcons.strokeRoundedInformationCircle)),
              Tab(text: 'E-books', icon: Icon(HugeIcons.strokeRoundedBook02)),
              Tab(text: 'Video Kitab', icon: Icon(HugeIcons.strokeRoundedVideo01)),
              Tab(text: 'Aktiviti', icon: Icon(HugeIcons.strokeRoundedAnalytics02)),
            ],
          ),
        ),
      ],
      body: _buildTabContent(),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: _user!.isAdmin
                ? Colors.purple.withValues(alpha: 0.1)
                : AppTheme.primaryColor.withValues(alpha: 0.1),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: _user!.avatarUrl ?? '',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Icon(
                  _user!.isAdmin
                      ? Icons.admin_panel_settings
                      : Icons.person,
                  size: 50,
                  color:
                      _user!.isAdmin ? Colors.purple : AppTheme.primaryColor,
                ),
                placeholder: (context, url) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _user!.fullName ?? 'Tiada Nama',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          if (_user!.email != null && _user!.email!.isNotEmpty)
            InkWell(
              onTap: () => _copyToClipboard(_user!.email!, 'Emel'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mail_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    _user!.email!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.copy, size: 14, color: Colors.grey),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildChip(
                _user!.isAdmin ? 'ADMIN' : 'PENGGUNA',
                _user!.isAdmin ? Colors.purple : AppTheme.textSecondaryColor,
              ),
              _buildChip(
                _user!.hasActiveSubscription
                    ? 'PREMIUM AKTIF'
                    : 'TIADA LANGGANAN',
                _user!.hasActiveSubscription
                    ? AppTheme.primaryColor
                    : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Bookmark',
                _totalBookmarks.toString(),
                onTap: () => _tabController.animateTo(1),
              ),
              _buildStatItem(
                'E-books',
                _ebookInteractions.length.toString(),
                onTap: () => _tabController.animateTo(1),
              ),
              _buildStatItem(
                'Video Kitab',
                _videoKitabInteractions.length.toString(),
                onTap: () => _tabController.animateTo(2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
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
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
          _buildSection('Maklumat Asas', [
            _buildDetailRow('ID Pengguna', _user!.id),
            _buildDetailRow('Nama Penuh', _user!.fullName ?? 'Tiada'),
            _buildDetailRow('Email', _user!.email ?? 'Tiada'),
            _buildDetailRow('Peranan', _user!.role.toUpperCase()),
            _buildDetailRow('Telefon', _user!.phoneNumber ?? 'Tiada'),
            _buildDetailRow('Tarikh Daftar', _formatFullDate(_user!.createdAt)),
            _buildDetailRow(
              'Kemaskini Terakhir',
              _formatFullDate(_user!.updatedAt),
            ),
          ]),

          if (_subscription != null) ...[
            const SizedBox(height: 24),
            _buildSection('Maklumat Langganan', [
              _buildDetailRow('Pelan', _subscription!.planDisplayName),
              _buildDetailRow('Status', _subscription!.status.toUpperCase()),
              _buildDetailRow(
                'Tarikh Mula',
                _formatFullDate(_subscription!.startDate),
              ),
              _buildDetailRow(
                'Tarikh Tamat',
                _formatFullDate(_subscription!.endDate),
              ),
              _buildDetailRow(
                'Hari Berbaki',
                '${_subscription!.daysRemaining} hari',
              ),
              _buildDetailRow('Jumlah', _subscription!.formattedAmount),
              // Note: autoRenew & paymentMethod fields tidak wujud dalam database
              // _buildDetailRow(
              //   'Pembaharuan Auto',
              //   _subscription!.autoRenew ? 'Ya' : 'Tidak',
              // ),
              // _buildDetailRow(
              //   'Kaedah Bayar',
              //   _subscription!.paymentMethod ?? 'Tiada',
              // ),
            ]),
          ] else ...[
            const SizedBox(height: 24),
            _buildSection('Maklumat Langganan', [
              _buildDetailRow('Status', 'TIADA LANGGANAN AKTIF'),
            ]),
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

    return RefreshIndicator(
      onRefresh: _refreshEbooks,
      child: ListView.builder(
        controller: _ebookScrollController,
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
                Text(
                  '${(interaction['progress_percentage'] ?? 0).toInt()}% selesai',
                ),
              ],
            ),
            trailing: Text(
              _formatDate(DateTime.parse(interaction['updated_at'])),
            ),
            isThreeLine: true,
          ),
        );
      },
      ),
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

    return RefreshIndicator(
      onRefresh: _refreshVideos,
      child: ListView.builder(
        controller: _videoScrollController,
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
                Text(
                  '${(interaction['overall_progress_percentage'] ?? 0).toInt()}% selesai',
                ),
              ],
            ),
            trailing: Text(
              _formatDate(DateTime.parse(interaction['updated_at'])),
            ),
            isThreeLine: true,
          ),
        );
      },
      ),
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
    allInteractions.sort(
      (a, b) => DateTime.parse(
        b['updated_at'],
      ).compareTo(DateTime.parse(a['updated_at'])),
    );

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

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
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
                  Row(
                    children: [
                      Icon(HugeIcons.strokeRoundedBook02, size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 4),
                      Text('Disimpan', style: TextStyle(color: AppTheme.primaryColor)),
                    ],
                  ),
                if (activity['user_notes'] != null &&
                    activity['user_notes'].toString().isNotEmpty)
                  Row(
                    children: [
                      Icon(HugeIcons.strokeRoundedEdit02, size: 16, color: AppTheme.textSecondaryColor),
                      const SizedBox(width: 4),
                      const Text('Ada catatan'),
                    ],
                  ),
              ],
            ),
            trailing: Text(_formatDate(DateTime.parse(activity['updated_at']))),
            isThreeLine: true,
          ),
        );
      },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
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
      return '${difference.inMinutes} minit lalu';
    } else {
      return 'Baru sahaja';
    }
  }

  String _formatFullDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  // Helpers
  Future<void> _refreshEbooks() async {
    try {
      final data = await SupabaseService.from('ebook_user_interactions')
          .select('''
            id, is_saved, is_downloaded, created_at, updated_at,
            ebooks!ebook_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(0, _pageSize - 1);
      setState(() {
        _ebookPage = 1;
        _ebooksHasMore = (data as List).length == _pageSize;
        _ebookInteractions = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  Future<void> _refreshVideos() async {
    try {
      final data = await SupabaseService.from('video_kitab_user_interactions')
          .select('''
            id, is_saved, created_at, updated_at,
            video_kitab!video_kitab_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(0, _pageSize - 1);
      setState(() {
        _videoPage = 1;
        _videosHasMore = (data as List).length == _pageSize;
        _videoKitabInteractions = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _refreshEbooks(),
      _refreshVideos(),
    ]);
  }

  void _onEbookScroll() {
    if (!_ebooksHasMore || _loadingMoreEbooks) return;
    if (_ebookScrollController.position.pixels >=
        _ebookScrollController.position.maxScrollExtent - 200) {
      _loadMoreEbooks();
    }
  }

  void _onVideoScroll() {
    if (!_videosHasMore || _loadingMoreVideos) return;
    if (_videoScrollController.position.pixels >=
        _videoScrollController.position.maxScrollExtent - 200) {
      _loadMoreVideos();
    }
  }

  Future<void> _loadMoreEbooks() async {
    setState(() => _loadingMoreEbooks = true);
    try {
      final from = _ebookPage * _pageSize;
      final to = from + _pageSize - 1;
      final data = await SupabaseService.from('ebook_user_interactions')
          .select('''
            id, is_saved, is_downloaded, created_at, updated_at,
            ebooks!ebook_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(from, to);
      final list = List<Map<String, dynamic>>.from(data as List);
      setState(() {
        _ebookInteractions.addAll(list);
        _ebookPage += 1;
        _ebooksHasMore = list.length == _pageSize;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingMoreEbooks = false);
    }
  }

  Future<void> _loadMoreVideos() async {
    setState(() => _loadingMoreVideos = true);
    try {
      final from = _videoPage * _pageSize;
      final to = from + _pageSize - 1;
      final data = await SupabaseService.from('video_kitab_user_interactions')
          .select('''
            id, is_saved, created_at, updated_at,
            video_kitab!video_kitab_id (id, title, author)
          ''')
          .eq('user_id', widget.userId)
          .order('updated_at', ascending: false)
          .range(from, to);
      final list = List<Map<String, dynamic>>.from(data as List);
      setState(() {
        _videoKitabInteractions.addAll(list);
        _videoPage += 1;
        _videosHasMore = list.length == _pageSize;
      });
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _loadingMoreVideos = false);
    }
  }

  Future<void> _copyToClipboard(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label disalin')),
    );
  }

  void _onMenuSelected(String value) async {
    switch (value) {
      case 'reset_password':
        if (_user?.email != null && _user!.email!.isNotEmpty) {
          try {
            await SupabaseService.resetPassword(_user!.email!);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emel reset password dihantar')),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gagal hantar reset password: $e')),
            );
          }
        }
        break;
      case 'resend_verification':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fungsi verifikasi memerlukan endpoint server')),
        );
        break;
      case 'ban_user':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ban pengguna belum diimplementasi')),
        );
        break;
    }
  }
}
