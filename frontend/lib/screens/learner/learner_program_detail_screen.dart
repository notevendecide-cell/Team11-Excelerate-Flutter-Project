import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

  static const _pageSize = 20;
  final Map<String?, _ModuleTasksState> _moduleTasks = {};
  final Map<String, _ModuleChaptersState> _moduleChapters = {};

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

        _moduleTasks.clear();
        _moduleChapters.clear();
        // Include a "General" bucket for deliverables not assigned to a module.
        _moduleTasks[null] = _ModuleTasksState();
        for (final m in _milestones) {
          final id = m['id'] as String;
          _moduleTasks[id] = _ModuleTasksState();
          _moduleChapters[id] = _ModuleChaptersState();
        }
      });

      await _loadReviewIfEligible();
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

  Future<void> _loadModuleTasks(String? moduleId, {required bool reset}) async {
    final state = _moduleTasks[moduleId];
    if (state == null) return;
    if (state.loadingMore) return;
    if (!reset && !state.hasMore) return;

    setState(() {
      if (reset) {
        state.loading = true;
      } else {
        state.loadingMore = true;
      }
    });

    try {
      final nextOffset = reset ? 0 : state.offset;
      final query = <String, String>{
        'limit': '$_pageSize',
        'offset': '$nextOffset',
      };
      if (moduleId != null) query['milestoneId'] = moduleId;

      final json = await widget.api.get('/learner/programs/${widget.programId}/tasks', query: query);
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        if (reset) state.items.clear();
        state.items.addAll(items);
        state.offset = nextOffset + items.length;
        state.hasMore = items.length == _pageSize;
        state.loadedOnce = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load deliverables', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          state.loading = false;
          state.loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadModuleChapters(String moduleId) async {
    final state = _moduleChapters[moduleId];
    if (state == null) return;
    if (state.loading || state.loadedOnce) return;

    setState(() => state.loading = true);
    try {
      final json = await widget.api.get('/learner/programs/${widget.programId}/modules/$moduleId/chapters');
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        state.items
          ..clear()
          ..addAll(items);
        state.loadedOnce = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load chapters', message: e.message);
    } finally {
      if (mounted) setState(() => state.loading = false);
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
                  Text('Modules', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (_milestones.isEmpty)
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No modules available yet.'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemCount: _milestones.length,
                      itemBuilder: (ctx, i) {
                        final m = _milestones[i];
                        final moduleId = m['id'] as String;
                        final moduleTitle = m['title']?.toString() ?? 'Module ${i + 1}';

                        final tasksState = _moduleTasks[moduleId];
                        final chaptersState = _moduleChapters[moduleId];

                        final taskItems = tasksState?.items ?? const <Map<String, dynamic>>[];
                        final approvedCount = taskItems
                            .where((t) => (t['submission_status']?.toString() ?? '') == 'approved')
                            .length;
                        final totalCount = taskItems.length;

                        return Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: ExpansionTile(
                            title: Text(moduleTitle),
                            subtitle: (tasksState?.loadedOnce ?? false)
                                ? Text('Deliverables: $approvedCount/$totalCount approved')
                                : const Text('Tap to view chapters & deliverables'),
                            onExpansionChanged: (expanded) {
                              if (!expanded) return;
                              if (chaptersState != null && !chaptersState.loadedOnce && !chaptersState.loading) {
                                _loadModuleChapters(moduleId);
                              }
                              if (tasksState != null && !tasksState.loadedOnce && !tasksState.loading) {
                                _loadModuleTasks(moduleId, reset: true);
                              }
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text('Chapters', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    if (chaptersState == null)
                                      const SizedBox.shrink()
                                    else if (chaptersState.loading && chaptersState.items.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Center(child: CircularProgressIndicator()),
                                      )
                                    else if (chaptersState.loadedOnce && chaptersState.items.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 10),
                                        child: Text('No chapters in this module.'),
                                      )
                                    else
                                      ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: chaptersState.items.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final ch = chaptersState.items[index];
                                          final title = ch['title']?.toString() ?? 'Chapter ${index + 1}';
                                          final bodyMd = ch['body_md']?.toString() ?? '';
                                          return Card(
                                            elevation: 0,
                                            color: Theme.of(context).colorScheme.surface,
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                                children: [
                                                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                                                  const SizedBox(height: 8),
                                                  MarkdownBody(
                                                    data: bodyMd,
                                                    selectable: true,
                                                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                                      p: Theme.of(context).textTheme.bodyMedium,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    const SizedBox(height: 14),
                                    Text('Deliverables', style: Theme.of(context).textTheme.titleSmall),
                                    const SizedBox(height: 8),
                                    if (tasksState == null)
                                      const SizedBox.shrink()
                                    else if (tasksState.loading && tasksState.items.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 10),
                                        child: Center(child: CircularProgressIndicator()),
                                      )
                                    else if (tasksState.loadedOnce && tasksState.items.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 10),
                                        child: Text('No deliverables (no submission required).'),
                                      )
                                    else
                                      Column(
                                        children: [
                                          ListView.separated(
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            itemCount: tasksState.items.length,
                                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                                            itemBuilder: (context, index) {
                                              final t = tasksState.items[index];
                                              final status = t['submission_status']?.toString() ?? 'not_submitted';
                                              final deadline = t['deadline_at']?.toString();
                                              return ListTile(
                                                tileColor: Theme.of(context).colorScheme.surface,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                title: Text(t['title']?.toString() ?? ''),
                                                subtitle: Text('Status: $status${deadline == null ? '' : '\nDeadline: $deadline'}'),
                                                trailing: const Icon(Icons.chevron_right),
                                                onTap: () => widget.openTask(t['id'] as String),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 10),
                                          if (tasksState.hasMore)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton(
                                                onPressed: tasksState.loadingMore
                                                    ? null
                                                    : () => _loadModuleTasks(moduleId, reset: false),
                                                child: tasksState.loadingMore
                                                    ? const SizedBox(
                                                        height: 18,
                                                        width: 18,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : const Text('Load more'),
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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

class _ModuleTasksState {
  final List<Map<String, dynamic>> items = [];
  int offset = 0;
  bool hasMore = true;
  bool loading = false;
  bool loadingMore = false;
  bool loadedOnce = false;
}

class _ModuleChaptersState {
  final List<Map<String, dynamic>> items = [];
  bool loading = false;
  bool loadedOnce = false;
}
