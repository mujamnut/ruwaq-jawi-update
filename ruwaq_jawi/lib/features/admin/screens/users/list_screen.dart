import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = _searchQuery;
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        await SupabaseService.from(
          'profiles',
        ).update({'role': 'admin'}).eq('id', user.id);

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
          content: Text('Jangan tinggalkan kosong'),
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
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimaryColor,
        centerTitle: false,
        titleSpacing: 0,
        title: const Padding(
          padding: EdgeInsets.only(left: 16),
          child: Text(
            'Urus Pengguna',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.2,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tapis',
            onPressed: _openFilterSheet,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedFilterMailCircle,
              color: AppTheme.textSecondaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                color: Colors.transparent,
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Cari pengguna mengikut nama, emel atau ID...',
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: AppTheme.neutralGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      color: AppTheme.textSecondaryColor.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddAdminSheet,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        tooltip: 'Add Admin',
        child: const HugeIcon(
          icon: HugeIcons.strokeRoundedUserAdd01,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: const AdminBottomNav(currentIndex: 3),
    );
  }

  // Removed multi-action sheet; FAB opens Add Admin sheet directly.

  void _openAddAdminSheet() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Add New Admin',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        color: Colors.grey,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Jangan tinggalkan kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: HugeIcon(
                        icon: HugeIcons.strokeRoundedMail01,
                        color: Colors.grey,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Jangan tinggalkan kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: HugeIcon(
                        icon: HugeIcons.strokeRoundedLockPassword,
                        color: Colors.grey,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Jangan tinggalkan kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          _createAdminUser(
                            nameController.text.trim(),
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedUserAdd01,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Add Admin',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Column(
        children: [
          AdminUsersStatsBar(
            totalUsers: _filteredUsers.length,
            activeSubscriptions: _filteredUsers
                .where((user) => _userSubscriptions[user.id] != null)
                .length,
          ),
          const Expanded(child: AdminUsersLoadingList()),
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

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tapis Pengguna',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedFilter != 'all')
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedFilter = 'all');
                            setModalState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'all',
                          'Semua',
                          HugeIcons.strokeRoundedGridView,
                          () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedFilter = 'all');
                            setModalState(() {});
                          },
                        ),
                        _buildFilterChip(
                          'active',
                          'Aktif',
                          HugeIcons.strokeRoundedCheckmarkCircle02,
                          () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedFilter = 'active');
                            setModalState(() {});
                          },
                        ),
                        _buildFilterChip(
                          'inactive',
                          'Tidak Aktif',
                          HugeIcons.strokeRoundedCancel01,
                          () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedFilter = 'inactive');
                            setModalState(() {});
                          },
                        ),
                        _buildFilterChip(
                          'admin',
                          'Admin',
                          HugeIcons.strokeRoundedUserSettings01,
                          () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedFilter = 'admin');
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    final isSelected = _selectedFilter == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  size: 16,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondaryColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
