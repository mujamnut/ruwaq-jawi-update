import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../services/popup_service.dart';

class SubscriptionBanner extends StatefulWidget {
  const SubscriptionBanner({super.key});

  @override
  State<SubscriptionBanner> createState() => _SubscriptionBannerState();
}

class _SubscriptionBannerState extends State<SubscriptionBanner> {
  bool _show = false;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _decideVisibility();
  }

  Future<void> _decideVisibility() async {
    try {
      final shouldShowDaily = await PopupService.shouldShowSubscriptionPromo();
      if (!shouldShowDaily) {
        if (mounted) setState(() => _show = false);
        return;
      }

      final hasActive = await SupabaseService.hasActiveSubscription();
      if (mounted) {
        setState(() => _show = !hasActive);
      }

      // Record that we've shown it today (for daily frequency control)
      if (_show && !_recorded) {
        final user = SupabaseService.currentUser;
        if (user != null) {
          await SupabaseService.upsertPopupTracking(
            userId: user.id,
            popupType: 'subscription_promo',
          );
        }
        _recorded = true;
      }
    } catch (_) {
      // Fail silent – banner just won't show
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFDA6A), Color(0xFFFFB84E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.9),
              ),
              child: Center(
                child: PhosphorIcon(
                  PhosphorIcons.crown(PhosphorIconsStyle.fill),
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Naik Taraf ke Premium',
                    style: TextStyle(
                      color: const Color(0xFF1D2433),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Akses tanpa had video & e‑book premium',
                    style: TextStyle(
                      color: const Color(0xFF344054),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => context.push('/subscription'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1D2433),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Langgan',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => setState(() => _show = false),
              icon: const Icon(Icons.close, size: 18, color: Color(0xFF1D2433)),
              tooltip: 'Tutup',
            ),
          ],
        ),
      ),
    );
  }
}

