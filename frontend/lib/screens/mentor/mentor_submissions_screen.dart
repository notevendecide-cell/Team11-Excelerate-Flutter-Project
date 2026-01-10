import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class MentorSubmissionsScreen extends StatefulWidget {
  final ApiClient api;
  final Future<void> Function(String submissionId) openReview;

  const MentorSubmissionsScreen({
    super.key,
    required this.api,
    required this.openReview,
  });

  @override
  State<MentorSubmissionsScreen> createState() => _MentorSubmissionsScreenState();
}

class _MentorSubmissionsScreenState extends State<MentorSubmissionsScreen> {
  static const _pageSize = 20;

  String? _status = 'submitted';

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
      final query = <String, String>{
        'limit': '$_pageSize',
        'offset': '$nextOffset',
      };
      if (_status != null) query['status'] = _status!;

      final json = await widget.api.get('/mentor/submissions', query: query);
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _offset = nextOffset + items.length;
        _hasMore = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load submissions', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _setStatus(String? status) {
    setState(() => _status = status);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submissions')),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'All', selected: _status == null, onTap: () => _setStatus(null)),
                const SizedBox(width: 10),
                _FilterChip(label: 'Submitted', selected: _status == 'submitted', onTap: () => _setStatus('submitted')),
                const SizedBox(width: 10),
                _FilterChip(label: 'Approved', selected: _status == 'approved', onTap: () => _setStatus('approved')),
                const SizedBox(width: 10),
                _FilterChip(label: 'Rejected', selected: _status == 'rejected', onTap: () => _setStatus('rejected')),
              ],
            ),
          ),
          Expanded(
            child: _loading
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

                        final s = _items[i];
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(s['task_title']?.toString() ?? ''),
                          subtitle: Text(
                            'Learner: ${s['learner_name'] ?? ''}\nStatus: ${s['status'] ?? ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final id = s['id'] as String?;
                            if (id == null) return;
                            await widget.openReview(id);
                            if (!mounted) return;
                            _load(reset: true);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
