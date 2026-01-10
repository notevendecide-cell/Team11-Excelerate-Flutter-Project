import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class LearnerPerformanceReportScreen extends StatefulWidget {
  final ApiClient api;

  const LearnerPerformanceReportScreen({super.key, required this.api});

  @override
  State<LearnerPerformanceReportScreen> createState() => _LearnerPerformanceReportScreenState();
}

class _LearnerPerformanceReportScreenState extends State<LearnerPerformanceReportScreen> {
  bool _loading = true;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/learner/performance-report');
      setState(() => _report = (json as Map<String, dynamic>)['report'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load report', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (report == null)
                    const Text('No data')
                  else
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(label: 'Approved', value: '${report['approved'] ?? 0}'),
                        _StatCard(label: 'Pending', value: '${report['pending'] ?? 0}'),
                        _StatCard(label: 'Rejected', value: '${report['rejected'] ?? 0}'),
                        _StatCard(label: 'Avg. score', value: '${report['average_score'] ?? 0}'),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Tip: scores and statuses are updated only after mentor review. If your report looks empty, submit a task and wait for review.',
                      ),
                    ),
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
