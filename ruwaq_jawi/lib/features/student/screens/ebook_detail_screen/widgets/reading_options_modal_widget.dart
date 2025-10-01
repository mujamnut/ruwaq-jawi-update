import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

class ReadingOptionsModalWidget extends StatelessWidget {
  final VoidCallback onReadOnline;
  final VoidCallback onDownload;

  const ReadingOptionsModalWidget({
    super.key,
    required this.onReadOnline,
    required this.onDownload,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onReadOnline,
    required VoidCallback onDownload,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ReadingOptionsModalWidget(
        onReadOnline: onReadOnline,
        onDownload: onDownload,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Pilihan Pembacaan',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: PhosphorIcon(
              PhosphorIcons.readCvLogo(),
              color: AppTheme.primaryColor,
            ),
            title: const Text('Baca Online'),
            subtitle: const Text('Baca langsung di aplikasi'),
            onTap: () {
              Navigator.pop(context);
              onReadOnline();
            },
          ),
          ListTile(
            leading: PhosphorIcon(
              PhosphorIcons.download(),
              color: AppTheme.primaryColor,
            ),
            title: const Text('Download & Baca'),
            subtitle: const Text('Download untuk membaca offline'),
            onTap: () {
              Navigator.pop(context);
              onDownload();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}