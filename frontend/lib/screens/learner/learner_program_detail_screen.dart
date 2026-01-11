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

  bool _loadingReview = false;
  bool _submittingReview = false;
  Map<String, dynamic>? _reviewStatus;
  int _reviewRating = 5;
  final TextEditingController _reviewController = TextEditingController();

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

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
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

      await _loadReviewIfEligible();

      await _loadTasks(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load program', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadReviewIfEligible() async {
    final completion = (_progress?['completionPercentage'] as num?)?.toInt() ?? 0;
    if (completion < 100) {
      if (mounted) {
        setState(() {
          _reviewStatus = null;
          _loadingReview = false;
        });
      }
      return;
    }

    setState(() => _loadingReview = true);
    try {
      final json = await widget.api.get('/learner/programs/${widget.programId}/review');
      if (!mounted) return;
      setState(() => _reviewStatus = json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load review', message: e.message);
    } finally {
      if (mounted) setState(() => _loadingReview = false);
    }
  }

  Future<void> _submitReview() async {
    final feedback = _reviewController.text.trim();
    setState(() => _submittingReview = true);
    try {
      await widget.api.post(
        '/learner/programs/${widget.programId}/review',
        body: {
          'rating': _reviewRating,
          'feedback': feedback,
        },
      );
      if (!mounted) return;
      await showAppInfoPopup(context, title: 'Thanks!', message: 'Your program review was submitted.');
      await _loadReviewIfEligible();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to submit review', message: e.message);
    } finally {
      if (mounted) setState(() => _submittingReview = false);
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
    final completionInt = (stats?['completionPercentage'] as num?)?.toInt() ?? 0;

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

                  const SizedBox(height: 18),
                  Text('Program review', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (completionInt < 100)
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Complete all program tasks to leave a review. Your completion is $completion%.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_loadingReview)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    _ProgramReviewCard(
                      status: _reviewStatus,
                      rating: _reviewRating,
                      onRatingChanged: (v) => setState(() => _reviewRating = v),
                      controller: _reviewController,
                      submitting: _submittingReview,
                      onSubmit: _submitReview,
                    ),
                ],
              ),
            ),
    );
  }
}

class _ProgramReviewCard extends StatelessWidget {
  final Map<String, dynamic>? status;
  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  const _ProgramReviewCard({
    required this.status,
    required this.rating,
    required this.onRatingChanged,
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.wifi_off),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Unable to load review status. Pull to refresh and try again.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final review = (status?['review'] as Map?)?.cast<String, dynamic>();
    final eligible = status?['eligible'] == true;
    final totalTasks = status?['totalTasks'];
    final approvedTasks = status?['approvedTasks'];

    if (review != null) {
      final r = (review['rating'] as num?)?.toInt() ?? 0;
      final feedback = review['feedback']?.toString() ?? '';
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your review', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(_stars(r), style: Theme.of(context).textTheme.titleMedium),
              if (feedback.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(feedback, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      );
    }

    if (!eligible) {
      return Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You can review after all tasks are approved ($approvedTasks/$totalTasks).',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Leave a review', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final v in [1, 2, 3, 4, 5])
                  ChoiceChip(
                    label: Text('$v'),
                    selected: rating == v,
                    onSelected: (_) => onRatingChanged(v),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Feedback (optional)',
                hintText: 'What went well? What could be improved?',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitting ? null : onSubmit,
                child: submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _stars(int rating) {
    final clamped = rating.clamp(0, 5);
    return List.generate(5, (i) => i < clamped ? '★' : '☆').join();
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
