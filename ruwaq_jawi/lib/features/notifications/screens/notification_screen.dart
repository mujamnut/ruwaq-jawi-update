import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/notifications_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // Load inbox on open
    Future.microtask(() =>
        context.read<NotificationsProvider>().loadInbox());
  }

  Future<void> _refresh() async {
    await context.read<NotificationsProvider>().loadInbox();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: Consumer<NotificationsProvider>(
        builder: (context, notifier, _) {
          final notifications = notifier.inbox;

          if (notifier.isLoading && notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notifier.error != null && notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(
                      notifier.error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('Cuba Lagi'),
                    )
                  ],
                ),
              ),
            );
          }

          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('Tiada notifikasi')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                final isRead = item.readAt != null;
                final title = item.notification.title;
                final body = item.notification.body;

                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Padam Notifikasi?'),
                        content: const Text('Anda pasti mahu padam notifikasi ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Padam'),
                          ),
                        ],
                      ),
                    );
                    return confirm == true;
                  },
                  onDismissed: (_) async {
                    await notifier.deleteNotification(item.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Notifikasi dipadam')),
                      );
                    }
                  },
                  child: Card(
                    color: isRead ? Colors.grey[200] : Colors.white,
                    child: ListTile(
                      onTap: () {
                        if (!isRead) notifier.markAsRead(item.id);
                      },
                      leading: isRead
                          ? const Icon(Icons.notifications_none)
                          : const Icon(Icons.notifications_active, color: Colors.blue),
                      title: Text(title),
                      subtitle: Text(body),
                      trailing: !isRead
                          ? IconButton(
                              icon: const Icon(Icons.done),
                              onPressed: () => notifier.markAsRead(item.id),
                              tooltip: 'Tandakan sudah baca',
                            )
                          : null,
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Padam Notifikasi?'),
                            content: const Text('Anda pasti mahu padam notifikasi ini?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Batal'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Padam'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await notifier.deleteNotification(item.id);
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
