import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class NotificationsScreen extends StatefulWidget {
  final ApiClient api;

  const NotificationsScreen({super.key, required this.api});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/notifications', auth: true, query: {'limit': '50', 'offset': '0'});
      final items = (json as Map<String, dynamic>)['items'] as List<dynamic>;
      setState(() => _items = items.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await widget.api.post('/notifications/$id/read', auth: true);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message);
    }
  }

  Future<void> _markReadLocal(String id) async {
    try {
      await widget.api.post('/notifications/$id/read', auth: true);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((n) => (n['id']?.toString() == id)
                ? {
                    ...n,
                    'read_at': DateTime.now().toUtc().toIso8601String(),
                  }
                : n)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final id = n['id']?.toString();
    final title = n['title']?.toString() ?? 'Notification';
    final body = n['body']?.toString() ?? '';
    final createdAt = n['created_at']?.toString();

    final when = (createdAt == null || createdAt.isEmpty) ? '' : '\n\nCreated: $createdAt';
    try {
      await showAppInfoPopup(context, title: title, message: '$body$when');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Unable to open notification');
      return;
    }

    if (!mounted) return;
    if (id != null && n['read_at'] == null) {
      await _markReadLocal(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('No notifications', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'Notifications appear when learners submit tasks and when mentors review submissions.\n\nPull down to refresh.',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (ctx, i) {
                        final n = items[i];
                        final readAt = n['read_at'];
                        final isUnread = readAt == null;
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: isUnread
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : const Icon(Icons.notifications_none),
                          title: Text(
                            n['title']?.toString() ?? 'Notification',
                            style: isUnread ? const TextStyle(fontWeight: FontWeight.w700) : null,
                          ),
                          subtitle: Text(n['body']?.toString() ?? ''),
                          trailing: readAt == null
                              ? TextButton(
                                  onPressed: () => _markRead(n['id'] as String),
                                  child: const Text('Mark read'),
                                )
                              : const Icon(Icons.done_all),
                          onTap: () => _openNotification(n),
                        );
                      },
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemCount: items.length,
                    ),
            ),
    );
  }
}
