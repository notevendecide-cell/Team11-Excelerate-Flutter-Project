import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class LearnerProgramDetailScreen extends StatefulWidget {
  final ApiClient api;
  final String programId;
  final void Function(String taskId) openTask;

  const LearnerProgramDetailScreen({
    super.key,
    required this.api,
    required this.programId,
    required this.openTask,
  });

  @override
  State<LearnerProgramDetailScreen> createState() => _LearnerProgramDetailScreenState();
}

class _LearnerProgramDetailScreenState extends State<LearnerProgramDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _milestones = const [];

  String? _selectedMilestoneId;

  static const _pageSize = 20;
  bool _loadingTasks = true;
  bool _loadingMoreTasks = false;
  bool _hasMoreTasks = true;
  int _tasksOffset = 0;
  final List<Map<String, dynamic>> _tasks = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final progress = await widget.api.get('/learner/programs/${widget.programId}/progress');
      final milestones = await widget.api.get('/learner/programs/${widget.programId}/milestones');

      setState(() {
        _progress = progress as Map<String, dynamic>;
        _milestones = ((milestones as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
      });

      await _loadTasks(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load program', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadTasks({required bool reset}) async {
    if (_loadingMoreTasks) return;
    if (!reset && !_hasMoreTasks) return;

    setState(() {
      if (reset) {
        _loadingTasks = true;
      } else {
        _loadingMoreTasks = true;
      }
    });

    try {
      final nextOffset = reset ? 0 : _tasksOffset;
      final query = <String, String>{
        'limit': '$_pageSize',
        'offset': '$nextOffset',
      };
      if (_selectedMilestoneId != null) query['milestoneId'] = _selectedMilestoneId!;

      final json = await widget.api.get('/learner/programs/${widget.programId}/tasks', query: query);
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _tasks.clear();
        _tasks.addAll(items);
        _tasksOffset = nextOffset + items.length;
        _hasMoreTasks = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load tasks', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loadingTasks = false;
          _loadingMoreTasks = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _progress;
    final completion = stats?['completionPercentage']?.toString() ?? '0';

    return Scaffold(
      appBar: AppBar(title: const Text('Program')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(label: 'Total tasks', value: '${stats?['total_tasks'] ?? 0}'),
                      _StatCard(label: 'Approved', value: '${stats?['approved'] ?? 0}'),
                      _StatCard(label: 'Pending', value: '${stats?['pending'] ?? 0}'),
                      _StatCard(label: 'Completion', value: '$completion%'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('Milestones', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          final selected = _selectedMilestoneId == null;
                          return ChoiceChip(
                            label: const Text('All'),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _selectedMilestoneId = null);
                              _loadTasks(reset: true);
                            },
                          );
                        }
                        final m = _milestones[i - 1];
                        final id = m['id'] as String;
                        final selected = _selectedMilestoneId == id;
                        return ChoiceChip(
                          label: Text(m['title']?.toString() ?? ''),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _selectedMilestoneId = id);
                            _loadTasks(reset: true);
                          },
                        );
                      },
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemCount: _milestones.length + 1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (_loadingTasks)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 22),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tasks.length + (_hasMoreTasks ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        if (i == _tasks.length) {
                          if (!_loadingMoreTasks) {
                            _loadTasks(reset: false);
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final t = _tasks[i];
                        final status = t['submission_status']?.toString() ?? 'not_submitted';
                        final deadline = t['deadline_at']?.toString();
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(t['title']?.toString() ?? ''),
                          subtitle: Text('Status: $status${deadline == null ? '' : '\nDeadline: $deadline'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.openTask(t['id'] as String),
                        );
                      },
                    ),
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
