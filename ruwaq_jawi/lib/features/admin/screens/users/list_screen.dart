import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/models/subscription.dart';
import '../../../../core/models/user_profile.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/admin_bottom_nav.dart';
import 'managers/admin_users_data_manager.dart';
import 'managers/admin_users_error_mapper.dart';
import 'widgets/admin_user_card.dart';
import 'widgets/admin_users_empty_state.dart';
import 'widgets/admin_users_error_view.dart';
import 'widgets/admin_users_loading_list.dart';
import 'widgets/admin_users_search_filters.dart';
import 'widgets/admin_users_stats_bar.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminUsersDataManager _dataManager = AdminUsersDataManager();
  final AdminUsersErrorMapper _errorMapper = AdminUsersErrorMapper();

  List<UserProfile> _users = [];
  Map<String, Subscription?> _userSubscriptions = {};
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      if (mounted) {
        context.go('/login');
      }
      return;
    }

    final isAdmin = await _dataManager.isUserAdmin(user.id);
    if (!mounted) return;

    if (!isAdmin) {
      context.go('/home');
      return;
    }

    await _loadFromCache();
    await _loadUsers();
  }

  Future<void> _loadFromCache() async {
    final cache = await _dataManager.loadCachedData();
    if (!mounted || cache == null) return;

    setState(() {
      _users = cache.users;
      _userSubscriptions = cache.userSubscriptions;
      _isLoading = false;
    });
  }

  Future<void> _loadUsers() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final data = await _dataManager.fetchUsersData();
      await _dataManager.cacheData(data);

      if (!mounted) return;

      setState(() {
        _users = data.users;
        _userSubscriptions = data.userSubscriptions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorMapper.messageFor(e);
        _isLoading = false;
      });
    }
  }

  List<UserProfile> get _filteredUsers {
    var filtered = _users;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return (user.fullName?.toLowerCase().contains(query) ?? false) ||
            (user.email?.toLowerCase().contains(query) ?? false) ||
            user.id.toLowerCase().contains(query);
      }).toList();
    }

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

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _handleUserAction(UserProfile user, String action) async {
    switch (action) {
      case 'view':
        _navigateToUserDetail(user);
        break;
      case 'activate':
        await _showActivateSubscriptionDialog();
        break;
      case 'deactivate':
        await _confirmDeactivateSubscription(user);
        break;
      case 'promote':
        await _promoteToAdmin(user);
        break;
    }
  }

  void _navigateToUserDetail(UserProfile user) {
    context.push('/admin/users/${user.id}');
  }

  Future<void> _showActivateSubscriptionDialog() async {
    if (!mounted) return;
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

  Future<void> _confirmDeactivateSubscription(UserProfile user) async {
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

    if (confirmed == true && mounted) {
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
        await SupabaseService.from('profiles')
            .update({'role': 'admin'}).eq('id', user.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.fullName} telah dijadikan admin'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadUsers();
      } catch (e) {
        if (!mounted) return;
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
                  color: Colors.blue.withValues(alpha: 0.1),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sila isi semua maklumat'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    if (!mounted) return;
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

    try {
      final response = await SupabaseService.client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await SupabaseService.from('profiles').insert({
          'id': response.user!.id,
          'full_name': name,
          'role': 'admin',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin "$name" berjaya dicipta'),
            backgroundColor: Colors.green,
          ),
        );

        await _loadUsers();
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ralat mencipta admin: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Urus Pengguna'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
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
          AdminUsersSearchFilters(
            searchQuery: _searchQuery,
            selectedFilter: _selectedFilter,
            onSearchChanged: _onSearchChanged,
            onFilterChanged: _onFilterChanged,
          ),
          AdminUsersStatsBar(
            totalUsers: _filteredUsers.length,
            activeSubscriptions: _filteredUsers
                .where((user) => _userSubscriptions[user.id] != null)
                .length,
          ),
          const Expanded(
            child: AdminUsersLoadingList(),
          ),
        ],
      );
    }

    if (_error != null) {
      final details = _errorMapper.detailsFor(_error!);
      return AdminUsersErrorView(
        icon: details.icon,
        title: details.title,
        message: _error!,
        onRetry: _loadUsers,
      );
    }

    final filteredUsers = _filteredUsers;

    return Column(
      children: [
        AdminUsersSearchFilters(
          searchQuery: _searchQuery,
          selectedFilter: _selectedFilter,
          onSearchChanged: _onSearchChanged,
          onFilterChanged: _onFilterChanged,
        ),
        AdminUsersStatsBar(
          totalUsers: filteredUsers.length,
          activeSubscriptions: filteredUsers
              .where((user) => _userSubscriptions[user.id] != null)
              .length,
        ),
        Expanded(
          child: filteredUsers.isEmpty
              ? AdminUsersEmptyState(hasSearchQuery: _searchQuery.isNotEmpty)
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final subscription = _userSubscriptions[user.id];
                      return AdminUserCard(
                        user: user,
                        subscription: subscription,
                        onView: () => _handleUserAction(user, 'view'),
                        onToggleSubscription: () => _handleUserAction(
                          user,
                          subscription != null ? 'deactivate' : 'activate',
                        ),
                        onPromote: user.isAdmin
                            ? null
                            : () => _handleUserAction(user, 'promote'),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
