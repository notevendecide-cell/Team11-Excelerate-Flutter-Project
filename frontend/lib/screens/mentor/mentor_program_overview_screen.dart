import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorProgramOverviewScreen extends StatefulWidget {
  final ApiClient api;
  final String programId;

  const MentorProgramOverviewScreen({super.key, required this.api, required this.programId});

  @override
  State<MentorProgramOverviewScreen> createState() => _MentorProgramOverviewScreenState();
}

class _MentorProgramOverviewScreenState extends State<MentorProgramOverviewScreen> {
  bool _loading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/mentor/programs/${widget.programId}/overview');
      setState(() => _data = (json as Map<String, dynamic>));
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load program', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final learners = ((_data?['learners'] ?? []) as List).cast<Map<String, dynamic>>();
    final tasks = ((_data?['tasks'] ?? []) as List).cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(title: const Text('Program overview')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Learners', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (learners.isEmpty)
                    const _EmptyHint('No learners assigned yet.')
                  else
                    ...learners.map(
                      (u) => Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          title: Text(u['full_name']?.toString() ?? ''),
                          subtitle: Text(u['email']?.toString() ?? ''),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (tasks.isEmpty)
                    const _EmptyHint('No tasks yet.')
                  else
                    ...tasks.map(
                      (t) => Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: ListTile(
                          title: Text(t['title']?.toString() ?? ''),
                          subtitle: Text(
                            'Pending: ${t['pending'] ?? 0} | Approved: ${t['approved'] ?? 0} | Rejected: ${t['rejected'] ?? 0}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
