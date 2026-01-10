import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class AdminUsersScreen extends StatefulWidget {
  final ApiClient api;

  const AdminUsersScreen({super.key, required this.api});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _pageSize = 20;

  String? _role;

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
      if (_role != null) query['role'] = _role!;

      final json = await widget.api.get('/admin/users', query: query);
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _offset = nextOffset + items.length;
        _hasMore = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load users', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _openCreateUser() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateUserDialog(api: widget.api),
    );

    if (created == true) {
      if (!mounted) return;
      showAppSnack(context, 'User created');
      _load(reset: true);
    }
  }

  void _setRole(String? role) {
    setState(() => _role = role);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage users'),
        actions: [
          IconButton(onPressed: _openCreateUser, icon: const Icon(Icons.person_add_alt_1)),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(label: 'All', selected: _role == null, onTap: () => _setRole(null)),
                const SizedBox(width: 10),
                _FilterChip(label: 'Learners', selected: _role == 'learner', onTap: () => _setRole('learner')),
                const SizedBox(width: 10),
                _FilterChip(label: 'Mentors', selected: _role == 'mentor', onTap: () => _setRole('mentor')),
                const SizedBox(width: 10),
                _FilterChip(label: 'Admins', selected: _role == 'admin', onTap: () => _setRole('admin')),
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

                        final u = _items[i];
                        return ListTile(
                          tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(u['full_name']?.toString() ?? ''),
                          subtitle: Text('${u['email'] ?? ''}\nRole: ${u['role'] ?? ''}'),
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

class _CreateUserDialog extends StatefulWidget {
  final ApiClient api;

  const _CreateUserDialog({required this.api});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'Password123!');
  final _fullName = TextEditingController();
  String _role = 'learner';
  bool _saving = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.post('/admin/users', body: {
        'email': _email.text.trim(),
        'password': _password.text,
        'role': _role,
        'fullName': _fullName.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Create user failed', message: e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create user', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullName,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Email required';
                  if (!value.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                items: const [
                  DropdownMenuItem(value: 'learner', child: Text('Learner')),
                  DropdownMenuItem(value: 'mentor', child: Text('Mentor')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'learner'),
                decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.security_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => (v ?? '').length < 6 ? 'Min 6 chars' : null,
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
    );
  }
}
