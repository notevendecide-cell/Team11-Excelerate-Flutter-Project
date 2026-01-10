import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorReviewScreen extends StatefulWidget {
  final ApiClient api;
  final String submissionId;

  const MentorReviewScreen({super.key, required this.api, required this.submissionId});

  @override
  State<MentorReviewScreen> createState() => _MentorReviewScreenState();
}

class _MentorReviewScreenState extends State<MentorReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedback = TextEditingController();
  final _score = TextEditingController();

  String _decision = 'approved';
  bool _submitting = false;
  bool _editing = false;

  bool _loading = true;
  Map<String, dynamic>? _submission;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/mentor/submissions/${widget.submissionId}');
      final submission = (json as Map<String, dynamic>)['submission'] as Map<String, dynamic>;

      final status = submission['status']?.toString();
      final decision = (status == 'approved' || status == 'rejected') ? status! : 'approved';

      setState(() {
        _submission = submission;
        _decision = decision;
        _editing = false;
      });

      if (_feedback.text.trim().isEmpty) {
        _feedback.text = submission['feedback_text']?.toString() ?? '';
      }
      if (_score.text.trim().isEmpty) {
        final score = submission['score'];
        if (score != null) _score.text = score.toString();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load submission', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _feedback.dispose();
    _score.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final score = _score.text.trim().isEmpty ? null : int.parse(_score.text.trim());
      await widget.api.post(
        '/mentor/submissions/${widget.submissionId}/review',
        body: {
          'decision': _decision,
          'feedbackText': _feedback.text.trim(),
          'score': score,
        },
      );
      if (!mounted) return;
      showAppSnack(context, 'Review saved');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Review failed', message: e.message);
    } catch (_) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Review failed', message: 'Invalid score or request');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _submission;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review submission'),
        actions: [
          TextButton.icon(
            onPressed: _loading
                ? null
                : () {
                    setState(() => _editing = !_editing);
                  },
            icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit_outlined),
            label: Text(_editing ? 'View' : 'Edit'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (s != null)
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['task_title']?.toString() ?? '', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text('Learner: ${s['learner_name'] ?? ''}'),
                            if ((s['link'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Link: ${s['link']}'),
                            ],
                            if ((s['notes'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Notes: ${s['notes']}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _decision,
                              items: const [
                                DropdownMenuItem(value: 'approved', child: Text('Approve')),
                                DropdownMenuItem(value: 'rejected', child: Text('Reject')),
                              ],
                              onChanged: _editing ? (v) => setState(() => _decision = v ?? 'approved') : null,
                              decoration: const InputDecoration(
                                labelText: 'Decision',
                                prefixIcon: Icon(Icons.check_circle_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _score,
                              keyboardType: TextInputType.number,
                              enabled: _editing,
                              decoration: const InputDecoration(
                                labelText: 'Score (0-100)',
                                prefixIcon: Icon(Icons.score_outlined),
                              ),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) return null;
                                final parsed = int.tryParse(value);
                                if (parsed == null) return 'Enter a number';
                                if (parsed < 0 || parsed > 100) return '0 to 100 only';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _feedback,
                              minLines: 4,
                              maxLines: 8,
                              enabled: _editing,
                              decoration: const InputDecoration(
                                labelText: 'Feedback',
                                prefixIcon: Icon(Icons.feedback_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_editing)
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
                                      : const Text('Save review'),
                                ),
                              )
                            else
                              Text(
                                'View-only. Tap Edit to update the review.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
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
