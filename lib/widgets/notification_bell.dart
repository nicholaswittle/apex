import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:apex/theme.dart';
import '../core/notification_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _supabase = Supabase.instance.client;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .listen((_) => _refreshCount());
  }

  Future<void> _refreshCount() async {
    final count = await NotificationService.unreadCount();
    if (mounted) setState(() => _unread = count);
  }

  Future<void> _openNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final rows = await _supabase
        .from('notifications')
        .select('id, title, body, created_at, read_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(25);

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: UniversalTheme.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final notifications = ((rows as List?)?.cast<Map<String, dynamic>>()) ?? [];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () async {
                        await NotificationService.markAllRead();
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _refreshCount();
                      },
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: notifications.isEmpty
                      ? const Center(child: Text('No notifications yet.'))
                      : ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final item = notifications[index];
                            final isUnread = item['read_at'] == null;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['title']?.toString() ?? '',
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(item['body']?.toString() ?? ''),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await NotificationService.markAllRead();
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _openNotifications,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
      ),
    );
  }
}
