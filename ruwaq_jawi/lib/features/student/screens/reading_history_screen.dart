import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/kitab_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/kitab.dart';

class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final kitabProvider = context.read<KitabProvider>();

      final userId = auth.currentUserId;
      if (userId != null) {
        await kitabProvider.loadUserProgress(userId);
      }
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppTheme.textPrimaryColor,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Reading History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      body: Consumer<KitabProvider>(
        builder: (context, kp, _) {
          if (_loading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }

          final recent = kp.getRecentlyAccessedKitab(limit: 50);

          if (recent.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, color: AppTheme.textSecondaryColor, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Tiada sejarah bacaan',
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final kitab = recent[index];
              final progress = kp.userProgress[kitab.id];
              return _buildHistoryTile(kitab, lastAccessed: progress?.lastAccessed);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: recent.length,
          );
        },
      ),
    );
  }

  Widget _buildHistoryTile(Kitab kitab, {DateTime? lastAccessed}) {
    String subtitle = '—';
    if (lastAccessed != null) {
      final diff = DateTime.now().difference(lastAccessed);
      if (diff.inMinutes < 60) {
        subtitle = '${diff.inMinutes} min ago';
      } else if (diff.inHours < 24) {
        subtitle = '${diff.inHours} hours ago';
      } else {
        subtitle = '${diff.inDays} days ago';
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/kitab/${kitab.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: kitab.thumbnailUrl != null && kitab.thumbnailUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        kitab.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.menu_book, color: AppTheme.primaryColor),
                      ),
                    )
                  : Icon(Icons.menu_book, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kitab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

