import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:convert';
import '../../../core/services/supabase_service.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/models/subscription.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_bottom_nav.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<UserProfile> _users = [];
  Map<String, Subscription?> _userSubscriptions = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadFromCache();
    _loadUsers();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUsers = prefs.getString('cached_admin_users');
      final cachedSubscriptions = prefs.getString('cached_user_subscriptions');

      if (cachedUsers != null && cachedSubscriptions != null) {
        final usersJson = jsonDecode(cachedUsers) as List;
        final subscriptionsJson =
            jsonDecode(cachedSubscriptions) as Map<String, dynamic>;

        final users = usersJson
            .map((json) => UserProfile.fromJson(json))
            .toList();
        final subscriptions = <String, Subscription?>{};

        subscriptionsJson.forEach((key, value) {
          subscriptions[key] = value != null
              ? Subscription.fromJson(value)
              : null;
        });

        setState(() {
          _users = users;
          _userSubscriptions = subscriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cached users: $e');
    }
  }

  Future<void> _cacheData(
    List<UserProfile> users,
    Map<String, Subscription?> subscriptions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final usersJson = users.map((user) => user.toJson()).toList();
      final subscriptionsJson = <String, dynamic>{};

      subscriptions.forEach((key, value) {
        subscriptionsJson[key] = value?.toJson();
      });

      await prefs.setString('cached_admin_users', jsonEncode(usersJson));
      await prefs.setString(
        'cached_user_subscriptions',
        jsonEncode(subscriptionsJson),
      );
    } catch (e) {
      print('Error caching users: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load all user profiles with real email from auth.users
      List usersResponse;
      try {
        usersResponse =
            await SupabaseService.client.rpc('get_all_profiles_with_email')
                as List;
      } catch (e) {
        // Fallback to normal profiles query if RPC fails
        print('RPC failed, using fallback: $e');
        final profilesResponse = await SupabaseService.from(
          'profiles',
        ).select().order('created_at', ascending: false);

        usersResponse = (profilesResponse as List).map((json) {
          // Add dummy email as fallback
          final updatedJson = Map<String, dynamic>.from(json);
          updatedJson['email'] =
              '${json['full_name']?.toString().toLowerCase().replaceAll(' ', '')}@domain.com';
          return updatedJson;
        }).toList();
      }

      final users = usersResponse
          .map((json) => UserProfile.fromJson(json))
          .toList();

      // Load active subscriptions for each user
      final subscriptionsResponse = await SupabaseService.from('subscriptions')
          .select()
          .eq('status', 'active')
          .gt('current_period_end', DateTime.now().toIso8601String());

      final subscriptions = (subscriptionsResponse as List)
          .map((json) => Subscription.fromJson(json))
          .toList();

      // Map subscriptions to users
      final userSubscriptionMap = <String, Subscription?>{};
      for (final user in users) {
        userSubscriptionMap[user.id] = subscriptions
            .where((sub) => sub.userId == user.id)
            .firstOrNull;
      }

      // Cache the data
      await _cacheData(users, userSubscriptionMap);

      setState(() {
        _users = users;
        _userSubscriptions = userSubscriptionMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = _getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Connection related errors
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'Tiada sambungan internet. Sila semak sambungan anda dan cuba lagi.';
    }

    // Authentication errors
    if (errorString.contains('authretryablefetchexception') ||
        errorString.contains('invalid_grant') ||
        errorString.contains('unauthorized')) {
      return 'Sesi anda telah tamat. Sila log masuk semula.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Pelayan mengalami masalah. Sila cuba lagi dalam beberapa minit.';
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return 'Permintaan mengambil masa terlalu lama. Sila cuba lagi.';
    }

    // Generic network error
    if (errorString.contains('clientexception') ||
        errorString.contains('httperror')) {
      return 'Masalah sambungan rangkaian. Sila semak sambungan internet anda.';
    }

    // Default fallback
    return 'Ralat tidak dijangka berlaku. Sila cuba lagi atau hubungi sokongan teknikal.';
  }

  IconData _getErrorIcon(String error) {
    if (error.contains('sambungan internet') ||
        error.contains('sambungan rangkaian')) {
      return HugeIcons.strokeRoundedWifiDisconnected02;
    } else if (error.contains('sesi') || error.contains('log masuk')) {
      return HugeIcons.strokeRoundedLockPassword;
    } else if (error.contains('pelayan') || error.contains('server')) {
      return HugeIcons.strokeRoundedCloud;
    } else if (error.contains('masa terlalu lama') ||
        error.contains('timeout')) {
      return HugeIcons.strokeRoundedClock01;
    }
    return HugeIcons.strokeRoundedAlert02;
  }

  String _getErrorTitle(String error) {
    if (error.contains('sambungan internet') ||
        error.contains('sambungan rangkaian')) {
      return 'Tiada Sambungan Internet';
    } else if (error.contains('sesi') || error.contains('log masuk')) {
      return 'Sesi Tamat Tempoh';
    } else if (error.contains('pelayan') || error.contains('server')) {
      return 'Masalah Pelayan';
    } else if (error.contains('masa terlalu lama') ||
        error.contains('timeout')) {
      return 'Sambungan Terputus';
    }
    return 'Ralat Sistem';
  }

  List<UserProfile> get _filteredUsers {
    var filtered = _users;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return (user.fullName?.toLowerCase().contains(query) ?? false) ||
            (user.email?.toLowerCase().contains(query) ?? false) ||
            user.id.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'active':
        filtered = filtered
            .where((user) => _userSubscriptions[user.id] != null)
            .toList();
        break;
      case 'inactive':
        filtered = filtered
            .where((user) => _userSubscriptions[user.id] == null)
            .toList();
        break;
      case 'admin':
        filtered = filtered.where((user) => user.isAdmin).toList();
        break;
      case 'student':
        filtered = filtered.where((user) => user.isStudent).toList();
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Urus Pengguna'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        actions: [],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAdminDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        tooltip: 'Tambah Admin',
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedUserSettings01,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 3),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        children: [
          _buildSearchAndFilters(),
          _buildStatsBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 6, // Show 6 skeleton items
              itemBuilder: (context, index) => _buildUserSkeleton(),
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getErrorIcon(_error!),
                  size: 48.0,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _getErrorTitle(_error!),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: AppTheme.textLightColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text('Cuba Lagi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSearchAndFilters(),
        _buildStatsBar(),
        Expanded(child: _buildUsersList()),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari nama atau email pengguna...',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                color: Colors.grey,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: AppTheme.backgroundColor,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                _buildFilterChip('Langganan Aktif', 'active'),
                _buildFilterChip('Tiada Langganan', 'inactive'),
                _buildFilterChip('Admin', 'admin'),
                _buildFilterChip('Pelajar', 'student'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? value : 'all';
          });
        },
        selectedColor: AppTheme.primaryColor.withOpacity(0.2),
        backgroundColor: AppTheme.backgroundColor,
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected
              ? AppTheme.primaryColor
              : AppTheme.textSecondaryColor,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final filteredCount = _filteredUsers.length;
    final activeSubsCount = _filteredUsers
        .where((user) => _userSubscriptions[user.id] != null)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withOpacity(0.05),
      child: Row(
        children: [
          Text(
            '$filteredCount pengguna',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, color: AppTheme.borderColor),
          const SizedBox(width: 16),
          Text(
            '$activeSubsCount aktif',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final filteredUsers = _filteredUsers;

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedUserMultiple,
              size: 64.0,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tiada pengguna ditemui'
                  : 'Belum ada pengguna',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Cuba cari dengan nama lain'
                  : 'Pengguna akan muncul di sini setelah mendaftar',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredUsers.length,
        itemBuilder: (context, index) {
          return _buildUserCard(filteredUsers[index]);
        },
      ),
    );
  }

  Widget _buildUserCard(UserProfile user) {
    final subscription = _userSubscriptions[user.id];
    final hasActiveSubscription = subscription != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: () => _navigateToUserDetail(user),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: user.isAdmin
                        ? Colors.purple.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    child: HugeIcon(
                      icon: user.isAdmin
                          ? HugeIcons.strokeRoundedUserSettings01
                          : HugeIcons.strokeRoundedUser,
                      color: user.isAdmin
                          ? Colors.purple
                          : AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName ?? 'Tiada Nama',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email ?? 'No email',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreVertical,
                      color: AppTheme.textSecondaryColor,
                    ),
                    onSelected: (value) => _handleUserAction(user, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedView,
                              color: Colors.blue,
                            ),
                            SizedBox(width: 8),
                            Text('Lihat Detail'),
                          ],
                        ),
                      ),
                      if (!user.isAdmin) ...[
                        PopupMenuItem(
                          value: hasActiveSubscription
                              ? 'deactivate'
                              : 'activate',
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: hasActiveSubscription
                                    ? HugeIcons.strokeRoundedCancel01
                                    : HugeIcons.strokeRoundedCheckmarkCircle02,
                                color: hasActiveSubscription
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                hasActiveSubscription
                                    ? 'Batalkan Langganan'
                                    : 'Aktifkan Langganan',
                              ),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'promote',
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedUserSettings01,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text('Jadikan Admin'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.isAdmin
                          ? Colors.purple.withOpacity(0.2)
                          : Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: user.isAdmin ? Colors.purple : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: hasActiveSubscription
                          ? Colors.green.withOpacity(0.2)
                          : Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hasActiveSubscription ? 'AKTIF' : 'TIADA LANGGANAN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasActiveSubscription
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(user.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              if (hasActiveSubscription) ...[
                const SizedBox(height: 8),
                Text(
                  'Langganan: ${subscription.planDisplayName} (${subscription.daysRemaining} hari lagi)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
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

  void _navigateToUserDetail(UserProfile user) {
    context.push('/admin/users/${user.id}');
  }

  void _handleUserAction(UserProfile user, String action) async {
    switch (action) {
      case 'view':
        _navigateToUserDetail(user);
        break;
      case 'activate':
        await _activateSubscription(user);
        break;
      case 'deactivate':
        await _deactivateSubscription(user);
        break;
      case 'promote':
        await _promoteToAdmin(user);
        break;
    }
  }

  Future<void> _activateSubscription(UserProfile user) async {
    // Show dialog to select plan and duration
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aktifkan Langganan'),
        content: const Text('Fungsi ini akan tersedia tidak lama lagi.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deactivateSubscription(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Batalkan Langganan'),
        content: Text('Batalkan langganan untuk ${user.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Implement subscription cancellation logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fungsi ini akan tersedia tidak lama lagi.'),
        ),
      );
    }
  }

  Future<void> _promoteToAdmin(UserProfile user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jadikan Admin'),
        content: Text('Jadikan ${user.fullName} sebagai admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Jadikan Admin'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseService.from(
          'profiles',
        ).update({'role': 'admin'}).eq('id', user.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} telah dijadikan admin'),
            backgroundColor: Colors.green,
          ),
        );

        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ralat: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAdminDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Admin Baharu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Penuh',
                  border: OutlineInputBorder(),
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedUser,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMail01,
                    color: Colors.grey,
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Kata Laluan',
                  border: OutlineInputBorder(),
                  prefixIcon: HugeIcon(
                    icon: HugeIcons.strokeRoundedLockPassword,
                    color: Colors.grey,
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedInformationCircle,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Admin baharu akan mempunyai akses penuh ke sistem.',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => _createAdminUser(
              nameController.text,
              emailController.text,
              passwordController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Tambah Admin'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAdminUser(
    String name,
    String email,
    String password,
  ) async {
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila isi semua maklumat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close dialog

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Mencipta admin baharu...'),
            ],
          ),
        ),
      );

      // Create user account via Supabase Auth signUp
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Create profile with admin role
        await SupabaseService.from('profiles').insert({
          'id': response.user!.id,
          'full_name': name,
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin "$name" berjaya dicipta'),
            backgroundColor: Colors.green,
          ),
        );

        _loadUsers(); // Refresh user list
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat mencipta admin: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildUserSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
