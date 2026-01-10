import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/auth_controller.dart';
import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class LearnerDashboardScreen extends StatefulWidget {
  final AuthController auth;
  final ApiClient api;
  final Future<void> Function() openNotifications;

  const LearnerDashboardScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.openNotifications,
  });

  @override
  State<LearnerDashboardScreen> createState() => _LearnerDashboardScreenState();
}

class _LearnerDashboardScreenState extends State<LearnerDashboardScreen> {
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
      final json = await widget.api.get('/learner/dashboard');
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
    final name = widget.auth.user?.fullName ?? widget.auth.user?.email ?? 'Learner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Dashboard'),
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
                      _StatCard(label: 'Pending Tasks', value: '${_data?['pendingTasks'] ?? 0}'),
                      _StatCard(label: 'Approved Tasks', value: '${_data?['approvedTasks'] ?? 0}'),
                      _StatCard(label: 'Completion', value: '${_data?['completionPercentage'] ?? 0}%'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/learner/performance'),
                      icon: const Icon(Icons.insights_outlined),
                      label: const Text('View performance report'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Active Programs', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/learner/programs'),
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('Browse all my programs'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...(((_data?['activePrograms'] ?? []) as List)
                      .cast<Map<String, dynamic>>()
                      .map(
                        (p) => Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: ListTile(
                            title: Text(p['title']?.toString() ?? ''),
                            subtitle: Text(p['description']?.toString() ?? ''),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final id = p['id'] as String?;
                              if (id != null) {
                                context.push('/learner/programs/$id');
                              }
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
