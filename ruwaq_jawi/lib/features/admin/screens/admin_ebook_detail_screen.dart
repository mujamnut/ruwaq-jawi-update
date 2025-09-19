import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminEbookDetailScreen extends StatefulWidget {
  final String ebookId;

  const AdminEbookDetailScreen({super.key, required this.ebookId});

  @override
  State<AdminEbookDetailScreen> createState() => _AdminEbookDetailScreenState();
}

class _AdminEbookDetailScreenState extends State<AdminEbookDetailScreen> {
  Map<String, dynamic>? _ebook;
  List<Map<String, dynamic>> _userInteractions = [];
  Map<String, dynamic>? _category;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEbookData();
  }

  Future<void> _loadEbookData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load e-book details with category
      final ebookResponse = await SupabaseService.from('ebooks')
          .select('''
            *,
            categories (
              id, name, description
            )
          ''')
          .eq('id', widget.ebookId)
          .single();

      // Load user interactions for this e-book (simplified without profile join)
      final interactionsResponse =
          await SupabaseService.from('ebook_user_interactions')
              .select('*')
              .eq('ebook_id', widget.ebookId)
              .order('last_accessed', ascending: false);

      setState(() {
        _ebook = ebookResponse;
        _category = ebookResponse['categories'];
        _userInteractions = List<Map<String, dynamic>>.from(
          interactionsResponse,
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ralat memuatkan data e-book: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_ebook?['title'] ?? 'Detail E-book'),
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
            Text('Memuatkan data e-book...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 64.0,
              color: Colors.red,
            ),
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
              onPressed: _loadEbookData,
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

    if (_ebook == null) {
      return const Center(child: Text('E-book tidak dijumpai'));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildEbookHeader(),
          _buildEbookDetails(),
          _buildUserInteractions(),
        ],
      ),
    );
  }

  Widget _buildEbookHeader() {
    final isActive = _ebook!['is_active'] ?? true;
    final isPremium = _ebook!['is_premium'] ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.withValues(alpha: 0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _ebook!['thumbnail_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _ebook!['thumbnail_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const HugeIcon(
                              icon: HugeIcons.strokeRoundedBook02,
                              size: 60.0,
                              color: Colors.grey,
                            );
                          },
                        ),
                      )
                    : const HugeIcon(
                        icon: HugeIcons.strokeRoundedBook02,
                        size: 60.0,
                        color: Colors.grey,
                      ),
              ),
              const SizedBox(width: 20),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _ebook!['title'] ?? 'Tanpa Judul',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_ebook!['author'] != null) ...[
                      Text(
                        'Oleh: ${_ebook!['author']}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_category != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _category!['name'],
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isActive ? 'Aktif' : 'Tidak Aktif',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Premium',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                'Muka Surat',
                '${_ebook!['total_pages'] ?? 0}',
                HugeIcons.strokeRoundedBook02,
              ),
              _buildStatItem(
                'Paparan',
                '${_ebook!['views_count'] ?? 0}',
                HugeIcons.strokeRoundedView,
              ),
              _buildStatItem(
                'Muat Turun',
                '${_ebook!['downloads_count'] ?? 0}',
                HugeIcons.strokeRoundedDownload01,
              ),
              _buildStatItem(
                'Pengguna',
                '${_userInteractions.length}',
                HugeIcons.strokeRoundedUser,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        HugeIcon(icon: icon, color: AppTheme.primaryColor, size: 24.0),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
        ),
      ],
    );
  }

  Widget _buildEbookDetails() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maklumat Detail',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('ID E-book', _ebook!['id']),
          if (_ebook!['description'] != null &&
              _ebook!['description'].toString().isNotEmpty)
            _buildDetailRow('Deskripsi', _ebook!['description']),
          _buildDetailRow(
            'Saiz Fail',
            _formatFileSize(_ebook!['pdf_file_size']),
          ),
          _buildDetailRow('URL PDF', _ebook!['pdf_url'] ?? 'Tiada'),
          _buildDetailRow('Urutan', '${_ebook!['sort_order'] ?? 0}'),
          _buildDetailRow(
            'Dicipta',
            _formatFullDate(DateTime.parse(_ebook!['created_at'])),
          ),
          _buildDetailRow(
            'Dikemas kini',
            _formatFullDate(DateTime.parse(_ebook!['updated_at'])),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInteractions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interaksi Pengguna (${_userInteractions.length})',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_userInteractions.isEmpty) ...[
            const Center(
              child: Column(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserMultiple,
                    size: 48.0,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 8),
                  Text('Tiada interaksi pengguna'),
                ],
              ),
            ),
          ] else ...[
            ...List.generate(_userInteractions.length, (index) {
              final interaction = _userInteractions[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.primaryColor.withValues(
                        alpha: 0.1,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        color: AppTheme.primaryColor,
                        size: 20.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengguna ID: ${interaction['user_id'].toString().substring(0, 8)}...',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Halaman ${interaction['current_page'] ?? 1}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textSecondaryColor,
                                    ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${(interaction['progress_percentage'] ?? 0).toInt()}% selesai',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                          if (interaction['is_saved'] == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              '💾 Disimpan',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.primaryColor),
                            ),
                          ],
                          if (interaction['folder_name'] != null &&
                              interaction['folder_name']
                                  .toString()
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '📁 Folder: ${interaction['folder_name']}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textSecondaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(DateTime.parse(interaction['last_accessed'])),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  String _formatFileSize(dynamic size) {
    if (size == null) return 'Tidak diketahui';

    final sizeInBytes = size is int ? size : int.tryParse(size.toString()) ?? 0;

    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
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
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
