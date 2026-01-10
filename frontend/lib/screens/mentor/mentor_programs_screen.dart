import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorProgramsScreen extends StatefulWidget {
  final ApiClient api;

  const MentorProgramsScreen({super.key, required this.api});

  @override
  State<MentorProgramsScreen> createState() => _MentorProgramsScreenState();
}

class _MentorProgramsScreenState extends State<MentorProgramsScreen> {
  static const _pageSize = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (_loadingMore) return;
    if (!reset && !_hasMore) return;

    setState(() {
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final nextOffset = reset ? 0 : _offset;
      final json = await widget.api.get('/mentor/programs', query: {
        'limit': '$_pageSize',
        'offset': '$nextOffset',
      });
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _offset = nextOffset + items.length;
        _hasMore = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load programs', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My programs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _items.length + (_hasMore ? 1 : 0),
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  if (i == _items.length) {
                    if (!_loadingMore) {
                      _load(reset: false);
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final p = _items[i];
                  return ListTile(
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(p['title']?.toString() ?? ''),
                    subtitle: Text('Learners: ${p['learner_count'] ?? 0} | Tasks: ${p['task_count'] ?? 0}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final id = p['id'] as String?;
                      if (id != null) context.push('/mentor/programs/$id');
                    },
                  );
                },
              ),
            ),
    );
  }
}
