import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class TaskDetailScreen extends StatefulWidget {
  final ApiClient api;
  final String taskId;

  const TaskDetailScreen({super.key, required this.api, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _task;

  final _formKey = GlobalKey<FormState>();
  final _link = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/learner/tasks/${widget.taskId}');
      final task = (json as Map<String, dynamic>)['task'] as Map<String, dynamic>;
      setState(() {
        _task = task;
        _link.text = (task['submission_link'] as String?) ?? '';
        _notes.text = (task['submission_notes'] as String?) ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load task', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    try {
      var link = _link.text.trim();
      if (link.isNotEmpty && !link.startsWith('http://') && !link.startsWith('https://')) {
        link = 'https://$link';
      }
      await widget.api.post(
        '/learner/tasks/${widget.taskId}/submit',
        body: {
          'link': link,
          'notes': _notes.text.trim(),
        },
      );
      if (!mounted) return;
      showAppSnack(context, 'Submitted');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Submission failed', message: e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final task = _task;
    if (task == null) {
      return const Scaffold(body: Center(child: Text('Task not found')));
    }

    final links = (task['resource_links'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];

    final submissionStatus = task['submission_status']?.toString() ?? 'not_submitted';
    final hasSubmitted = submissionStatus != 'not_submitted' && submissionStatus.isNotEmpty;
    final feedback = task['feedback_text']?.toString();
    final score = task['score']?.toString();
    final submittedLink = task['submission_link']?.toString();
    final submittedNotes = task['submission_notes']?.toString();

    return Scaffold(
      appBar: AppBar(title: Text(task['title']?.toString() ?? 'Task')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(task['description']?.toString() ?? '', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              title: const Text('Deadline'),
              subtitle: Text(task['deadline_at']?.toString() ?? ''),
            ),
          ),
          const SizedBox(height: 12),
          Text('Resources', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (links.isEmpty)
            Text('No links provided.', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...links.map(
              (l) => Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: Text(l),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: l));
                      if (!context.mounted) return;
                      showAppSnack(context, 'Copied');
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('Submission', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Status: $submissionStatus'),
                  if (score != null) Text('Score: $score'),
                  if (feedback != null && feedback.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('Feedback:', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(feedback),
                  ],
                  const SizedBox(height: 12),
                  if (hasSubmitted) ...[
                    if (submittedLink != null && submittedLink.isNotEmpty)
                      Card(
                        elevation: 0,
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: ListTile(
                          title: const Text('Submitted link'),
                          subtitle: Text(submittedLink),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: submittedLink));
                              if (!context.mounted) return;
                              showAppSnack(context, 'Copied');
                            },
                          ),
                        ),
                      ),
                    if (submittedNotes != null && submittedNotes.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Notes:', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text(submittedNotes),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      'Submission is locked after submitting.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _link,
                            decoration: const InputDecoration(
                              labelText: 'GitHub/Drive link',
                              prefixIcon: Icon(Icons.link),
                            ),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Link is required';
                              if (!value.startsWith('http') && !value.startsWith('www.')) return 'Enter a valid URL';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notes,
                            minLines: 3,
                            maxLines: 6,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                              prefixIcon: Icon(Icons.notes_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _submitting ? null : _submit,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
