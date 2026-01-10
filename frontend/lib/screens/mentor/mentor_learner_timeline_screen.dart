import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorLearnerTimelineScreen extends StatefulWidget {
  final ApiClient api;
  final String learnerId;

  const MentorLearnerTimelineScreen({super.key, required this.api, required this.learnerId});

  @override
  State<MentorLearnerTimelineScreen> createState() => _MentorLearnerTimelineScreenState();
}

class _MentorLearnerTimelineScreenState extends State<MentorLearnerTimelineScreen> {
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
      final json = await widget.api.get('/mentor/learners/${widget.learnerId}/timeline');
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load timeline', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Learner timeline')),
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
                                Text('No timeline yet', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'This timeline is generated from the learner\'s submissions and your reviews.\n\n'
                                  'To see items here: Admin assigns learner to a program → Admin creates tasks → Learner submits → Mentor reviews.',
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
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final t = items[i];
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(t['task_title']?.toString() ?? ''),
                          subtitle: Text('Status: ${t['status'] ?? ''}\nScore: ${t['score'] ?? '-'}'),
                        );
                      },
                    ),
            ),
    );
  }
}
