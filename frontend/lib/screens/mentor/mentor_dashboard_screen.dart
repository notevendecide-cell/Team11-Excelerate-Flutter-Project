import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth_controller.dart';
import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorDashboardScreen extends StatefulWidget {
  final AuthController auth;
  final ApiClient api;
  final Future<void> Function() openNotifications;

  const MentorDashboardScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.openNotifications,
  });

  @override
  State<MentorDashboardScreen> createState() => _MentorDashboardScreenState();
}

class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/mentor/dashboard');
      final unread = await widget.api.get('/notifications/unread-count', auth: true);
      setState(() {
        _data = (json as Map<String, dynamic>);
        _unreadNotifications = (unread as Map<String, dynamic>)['count'] as int? ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load dashboard', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _notificationsButton() {
    final count = _unreadNotifications;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () async {
            try {
              await widget.openNotifications();
              if (!mounted) return;
              await _load();
            } catch (_) {
              if (!mounted) return;
              showAppSnack(context, 'Unable to open notifications');
            }
          },
          icon: const Icon(Icons.notifications_none),
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.auth.user?.fullName ?? widget.auth.user?.email ?? 'Mentor';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mentor Dashboard'),
        actions: [
          _notificationsButton(),
          IconButton(onPressed: widget.auth.logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Welcome, $name', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      title: const Text('Pending reviews'),
                      trailing: Text('${_data?['pendingReviews'] ?? 0}', style: Theme.of(context).textTheme.titleLarge),
                      onTap: () async {
                        await context.push('/mentor/submissions');
                        if (!mounted) return;
                        await _load();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await context.push('/mentor/submissions');
                        if (!mounted) return;
                        await _load();
                      },
                      icon: const Icon(Icons.inbox_outlined),
                      label: const Text('Review submissions'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/mentor/programs'),
                      icon: const Icon(Icons.view_list_outlined),
                      label: const Text('View my programs'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Assigned learners', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ...(((_data?['assignedLearners'] ?? []) as List)
                      .cast<Map<String, dynamic>>()
                      .map(
                        (u) => Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: ListTile(
                            title: Text(u['full_name']?.toString() ?? ''),
                            subtitle: Text(u['email']?.toString() ?? ''),
                            trailing: const Icon(Icons.timeline),
                            onTap: () {
                              final id = u['id'] as String?;
                              if (id != null) context.push('/mentor/learners/$id/timeline');
                            },
                          ),
                        ),
                      )),
                ],
              ),
            ),
    );
  }
}
