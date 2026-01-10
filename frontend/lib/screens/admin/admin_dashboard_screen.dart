import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth_controller.dart';
import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AuthController auth;
  final ApiClient api;
  final Future<void> Function() openNotifications;

  const AdminDashboardScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.openNotifications,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _trends = const [];
  List<Map<String, dynamic>> _ranking = const [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trends = await widget.api.get('/admin/analytics/completion-trends');
      final ranking = await widget.api.get('/admin/analytics/learner-ranking');
      final unread = await widget.api.get('/notifications/unread-count', auth: true);

      setState(() {
        _trends = ((trends as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
        _ranking = ((ranking as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
        _unreadNotifications = (unread as Map<String, dynamic>)['count'] as int? ?? 0;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load analytics', message: e.message);
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
    final name = widget.auth.user?.fullName ?? widget.auth.user?.email ?? 'Admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin/users'),
                        icon: const Icon(Icons.group_outlined),
                        label: const Text('Manage users'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin/programs'),
                        icon: const Icon(Icons.school_outlined),
                        label: const Text('Manage programs'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/admin/audit-logs'),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Audit logs'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Completion trends (latest 12 weeks)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._trends.map(
                    (t) => Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        title: Text(t['week']?.toString() ?? ''),
                        subtitle: Text('approved: ${t['approved']} | submitted: ${t['submitted']} | rejected: ${t['rejected']}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Learner ranking', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._ranking.take(10).map(
                    (r) => Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        title: Text(r['full_name']?.toString() ?? ''),
                        subtitle: Text(r['email']?.toString() ?? ''),
                        trailing: Text('Approved: ${r['approved_count']}', style: Theme.of(context).textTheme.labelLarge),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
