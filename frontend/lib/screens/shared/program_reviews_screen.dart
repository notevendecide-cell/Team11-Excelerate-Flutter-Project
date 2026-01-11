import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class ProgramReviewsScreen extends StatefulWidget {
  final ApiClient api;
  final String title;
  final String endpointPath;

  const ProgramReviewsScreen({
    super.key,
    required this.api,
    required this.title,
    required this.endpointPath,
  });

  @override
  State<ProgramReviewsScreen> createState() => _ProgramReviewsScreenState();
}

class _ProgramReviewsScreenState extends State<ProgramReviewsScreen> {
  static const _pageSize = 20;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  Map<String, dynamic>? _summary;
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
      final json = await widget.api.get(
        widget.endpointPath,
        query: {
          'limit': '$_pageSize',
          'offset': '$nextOffset',
        },
      );

      final map = json as Map<String, dynamic>;
      final items = ((map['items'] ?? []) as List).cast<Map<String, dynamic>>();
      final summary = (map['summary'] as Map?)?.cast<String, dynamic>();

      if (!mounted) return;
      setState(() {
        _summary = summary;
        if (reset) _items.clear();
        _items.addAll(items);
        _offset = nextOffset + items.length;
        _hasMore = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load reviews', message: e.message);
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
    final totalReviews = _summary?['totalReviews']?.toString() ?? '0';
    final averageRating = _summary?['averageRating']?.toString() ?? '0.00';

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(label: 'Total reviews', value: totalReviews),
                      _StatCard(label: 'Average rating', value: averageRating),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Feedback', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'No reviews yet.',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == _items.length) {
                          if (!_loadingMore) {
                            _load(reset: false);
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final r = _items[index];
                        final learnerName = r['learner_name']?.toString() ?? '';
                        final learnerEmail = r['learner_email']?.toString() ?? '';
                        final rating = (r['rating'] as num?)?.toInt() ?? 0;
                        final feedback = r['feedback']?.toString() ?? '';
                        final createdAt = r['created_at']?.toString() ?? '';

                        return Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(learnerName, style: Theme.of(context).textTheme.titleSmall),
                                          if (learnerEmail.isNotEmpty)
                                            Text(
                                              learnerEmail,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(_stars(rating), style: Theme.of(context).textTheme.titleMedium),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  feedback.trim().isEmpty ? 'No feedback provided.' : feedback,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (createdAt.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    createdAt,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
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
