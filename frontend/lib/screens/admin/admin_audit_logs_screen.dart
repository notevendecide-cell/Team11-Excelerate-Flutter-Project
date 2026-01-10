import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class AdminAuditLogsScreen extends StatefulWidget {
  final ApiClient api;

  const AdminAuditLogsScreen({super.key, required this.api});

  @override
  State<AdminAuditLogsScreen> createState() => _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends State<AdminAuditLogsScreen> {
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
      final json = await widget.api.get('/admin/audit-logs', query: {
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
      await showAppErrorPopup(context, title: 'Failed to load audit logs', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final meta = item['meta'];
    final metaText = meta == null ? '{}' : const JsonEncoder.withIndent('  ').convert(meta);

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Audit log detail', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('Action: ${item['action'] ?? ''}'),
              Text('Actor: ${item['actor_name'] ?? item['actor_user_id'] ?? ''}'),
              Text('Entity: ${item['entity_type'] ?? '-'} ${item['entity_id'] ?? ''}'),
              Text('Created: ${item['created_at'] ?? ''}'),
              const SizedBox(height: 12),
              Text('Meta', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: Text(metaText, style: const TextStyle(fontFamily: 'monospace')),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit logs')),
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

                  final al = _items[i];
                  return ListTile(
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    title: Text(al['action']?.toString() ?? ''),
                    subtitle: Text(
                      'Actor: ${al['actor_name'] ?? al['actor_user_id'] ?? ''}\nEntity: ${al['entity_type'] ?? '-'}\nCreated: ${al['created_at'] ?? ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetails(al),
                  );
                },
              ),
            ),
    );
  }
}
