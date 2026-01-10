import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class AdminProgramsScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(String programId) openProgram;

  const AdminProgramsScreen({
    super.key,
    required this.api,
    required this.openProgram,
  });

  @override
  State<AdminProgramsScreen> createState() => _AdminProgramsScreenState();
}

class _AdminProgramsScreenState extends State<AdminProgramsScreen> {
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
      final json = await widget.api.get('/admin/programs', query: {
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
      appBar: AppBar(
        title: const Text('Manage programs'),
        actions: [
          IconButton(
            onPressed: () async {
              final created = await showDialog<bool>(
                context: context,
                builder: (ctx) => _CreateProgramDialog(api: widget.api),
              );
              if (created == true) {
                if (!context.mounted) return;
                showAppSnack(context, 'Program created');
                _load(reset: true);
              }
            },
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create program',
          ),
        ],
      ),
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
                    subtitle: Text('Mentor: ${p['mentor_name'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.openProgram(p['id'] as String),
                  );
                },
              ),
            ),
    );
  }
}

class _CreateProgramDialog extends StatefulWidget {
  final ApiClient api;

  const _CreateProgramDialog({required this.api});

  @override
  State<_CreateProgramDialog> createState() => _CreateProgramDialogState();
}

class _CreateProgramDialogState extends State<_CreateProgramDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  bool _loadingMentors = true;
  bool _saving = false;
  List<Map<String, dynamic>> _mentors = const [];
  String? _mentorId;

  @override
  void initState() {
    super.initState();
    _loadMentors();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadMentors() async {
    setState(() => _loadingMentors = true);
    try {
      final json = await widget.api.get('/admin/users', query: {
        'role': 'mentor',
        'limit': '50',
        'offset': '0',
      });
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _mentors = items;
        _mentorId = items.isNotEmpty ? items.first['id'] as String : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load mentors', message: e.message);
    } finally {
      if (mounted) setState(() => _loadingMentors = false);
    }
  }

  Future<void> _save() async {
    if (_mentorId == null) {
      await showAppErrorPopup(context, title: 'Missing mentor', message: 'Create a mentor user first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.post('/admin/programs', body: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'mentorId': _mentorId,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Create program failed', message: e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _loadingMentors
              ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
              : Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Create program', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _mentorId,
                        items: _mentors
                            .map(
                              (m) => DropdownMenuItem(
                                value: m['id'] as String,
                                child: Text(m['full_name']?.toString() ?? m['email']?.toString() ?? ''),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) => setState(() => _mentorId = v),
                        decoration: const InputDecoration(
                          labelText: 'Mentor',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.school_outlined)),
                        validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a title' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Create'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
