import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_theme.dart';

/// Screen untuk pilih mode penambahan Video Kitab
/// Manual Mode: Tambah episode satu per satu dengan kawalan penuh
/// Auto Mode: Sync automatic dari YouTube playlist
class AdminKitabModeSelectionScreen extends StatelessWidget {
  const AdminKitabModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Tambah Video Kitab'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textLightColor,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              const SizedBox(height: 24),
              Text(
                'Pilih Mod Penambahan',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Pilih cara untuk menambah video kitab baharu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Manual Mode Card
              Expanded(
                child: _ModeCard(
                  title: 'Manual Mode',
                  description:
                      'Tambah episode satu per satu dengan kawalan penuh. '
                      'Sesuai untuk kitab dengan episode terhad atau '
                      'memerlukan penyesuaian khusus.',
                  icon: HugeIcons.strokeRoundedPencilEdit01,
                  color: Colors.blue,
                  features: const [
                    'Tambah episode satu per satu',
                    'Kawalan penuh atas setiap episode',
                    'Boleh edit dan susun semula',
                    'Upload thumbnail & PDF manual',
                  ],
                  buttonText: 'Pilih Manual Mode',
                  onTap: () => context.push('/admin/kitabs/add-manual'),
                ),
              ),
              const SizedBox(height: 24),

              // Auto Mode Card
              Expanded(
                child: _ModeCard(
                  title: 'Auto Mode',
                  description:
                      'Sync automatic dari YouTube playlist. '
                      'Sesuai untuk kitab dengan banyak episode dari playlist.',
                  icon: PhosphorIconsRegular.lightning,
                  iconStyle: PhosphorIconsStyle.fill,
                  color: Colors.amber,
                  features: const [
                    'Sync automatic dari playlist',
                    'Semua episode ditambah sekaligus',
                    'Auto-extract metadata',
                    'Penjimatan masa untuk bulk import',
                  ],
                  buttonText: 'Pilih Auto Mode',
                  onTap: () => context.push('/admin/kitabs/add-auto'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final PhosphorIconsStyle? iconStyle;
  final Color color;
  final List<String> features;
  final String buttonText;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    this.iconStyle,
    required this.color,
    required this.features,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: iconStyle != null
                          ? PhosphorIcon(
                              icon as PhosphorIconData,
                              color: color,
                              size: 32,
                            )
                          : HugeIcon(
                              icon: icon,
                              color: color,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 20),

                // Features List
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: features.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: color,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                features[index],
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textPrimaryColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          HugeIcons.strokeRoundedArrowRight01,
                          size: 20,
                        ),
                      ],
                    ),
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
