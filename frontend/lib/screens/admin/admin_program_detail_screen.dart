import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class AdminProgramDetailScreen extends StatefulWidget {
  final ApiClient api;
  final String programId;

  const AdminProgramDetailScreen({
    super.key,
    required this.api,
    required this.programId,
  });

  @override
  State<AdminProgramDetailScreen> createState() => _AdminProgramDetailScreenState();
}

class _AdminProgramDetailScreenState extends State<AdminProgramDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _program;
  List<Map<String, dynamic>> _learners = const [];
  List<Map<String, dynamic>> _milestones = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final json = await widget.api.get('/admin/programs/${widget.programId}');
      setState(() {
        _program = (json as Map<String, dynamic>)['program'] as Map<String, dynamic>;
        _learners = (json['learners'] as List).cast<Map<String, dynamic>>();
        _milestones = (json['milestones'] as List).cast<Map<String, dynamic>>();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load program', message: e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignLearner() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AssignLearnerDialog(api: widget.api, programId: widget.programId),
    );

    if (!mounted) return;

    if (ok == true) {
      showAppSnack(context, 'Learner assigned');
      _load();
    }
  }

  Future<void> _createMilestone() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateMilestoneDialog(api: widget.api, programId: widget.programId),
    );

    if (!mounted) return;

    if (ok == true) {
      showAppSnack(context, 'Milestone created');
      _load();
    }
  }

  Future<void> _createTask() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateTaskDialog(api: widget.api, programId: widget.programId, milestones: _milestones),
    );

    if (!mounted) return;

    if (ok == true) {
      showAppSnack(context, 'Task created');
    }
  }

  Future<void> _changeMentor() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ChangeMentorDialog(api: widget.api, programId: widget.programId),
    );

    if (!mounted) return;

    if (ok == true) {
      showAppSnack(context, 'Mentor updated');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program detail'),
        actions: [
          IconButton(
            tooltip: 'Reviews',
            onPressed: () => context.push('/admin/programs/${widget.programId}/reviews'),
            icon: const Icon(Icons.star_outline),
          ),
          IconButton(onPressed: _assignLearner, icon: const Icon(Icons.person_add_alt_1)),
          IconButton(onPressed: _createMilestone, icon: const Icon(Icons.flag_outlined)),
          IconButton(onPressed: _createTask, icon: const Icon(Icons.playlist_add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(_program?['title']?.toString() ?? '', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: _assignLearner,
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Assign learner'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _changeMentor,
                                icon: const Icon(Icons.support_agent_outlined),
                                label: const Text('Change mentor'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _createMilestone,
                                icon: const Icon(Icons.flag_outlined),
                                label: const Text('Create milestone'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _createTask,
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('Create task'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Task assignment model: tasks belong to a program. Any learner assigned to the program automatically sees all tasks and can submit them.',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: ListTile(
                      title: const Text('Mentor'),
                      subtitle: Text(_program?['mentor_name']?.toString() ?? ''),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: _changeMentor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Learners', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._learners.map(
                    (l) => Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        title: Text(l['full_name']?.toString() ?? ''),
                        subtitle: Text(l['email']?.toString() ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Milestones', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._milestones.map(
                    (m) => Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        title: Text(m['title']?.toString() ?? ''),
                        subtitle: Text('Order: ${m['sort_order'] ?? 0}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AssignLearnerDialog extends StatefulWidget {
  final ApiClient api;
  final String programId;

  const _AssignLearnerDialog({required this.api, required this.programId});

  @override
  State<_AssignLearnerDialog> createState() => _AssignLearnerDialogState();
}

class _AssignLearnerDialogState extends State<_AssignLearnerDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool _loadingLearners = true;
  List<Map<String, dynamic>> _learners = const [];
  String? _learnerId;

  @override
  void initState() {
    super.initState();
    _loadLearners();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadLearners() async {
    setState(() => _loadingLearners = true);
    try {
      final json = await widget.api.get('/admin/users', query: {
        'role': 'learner',
        'limit': '50',
        'offset': '0',
      });
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _learners = items;
        _learnerId = items.isNotEmpty ? items.first['id'] as String : null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load learners', message: e.message);
    } finally {
      if (mounted) setState(() => _loadingLearners = false);
    }
  }

  Future<void> _save() async {
    if (_learnerId == null) {
      await showAppErrorPopup(context, title: 'No learners available', message: 'Create a learner user first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.post('/admin/programs/${widget.programId}/assign-learner', body: {
        'learnerId': _learnerId,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Assign failed', message: e.message);
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
        child: _loadingLearners
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Assign learner', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _learnerId,
                      items: _learners
                          .map(
                            (u) => DropdownMenuItem(
                              value: u['id'] as String,
                              child: Text(u['full_name']?.toString() ?? u['email']?.toString() ?? ''),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) => setState(() => _learnerId = v),
                      decoration: const InputDecoration(labelText: 'Learner', prefixIcon: Icon(Icons.person_outline)),
                      validator: (v) => v == null || v.isEmpty ? 'Select a learner' : null,
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
                                : const Text('Assign'),
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

class _ChangeMentorDialog extends StatefulWidget {
  final ApiClient api;
  final String programId;

  const _ChangeMentorDialog({required this.api, required this.programId});

  @override
  State<_ChangeMentorDialog> createState() => _ChangeMentorDialogState();
}

class _ChangeMentorDialogState extends State<_ChangeMentorDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool _loadingMentors = true;
  List<Map<String, dynamic>> _mentors = const [];
  String? _mentorId;

  @override
  void initState() {
    super.initState();
    _loadMentors();
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
      await showAppErrorPopup(context, title: 'No mentors available', message: 'Create a mentor user first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.post('/admin/programs/${widget.programId}/assign-mentor', body: {
        'mentorId': _mentorId,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Update failed', message: e.message);
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
        child: _loadingMentors
            ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Change mentor', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _mentorId,
                      items: _mentors
                          .map(
                            (u) => DropdownMenuItem(
                              value: u['id'] as String,
                              child: Text(u['full_name']?.toString() ?? u['email']?.toString() ?? ''),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (v) => setState(() => _mentorId = v),
                      decoration: const InputDecoration(labelText: 'Mentor', prefixIcon: Icon(Icons.support_agent_outlined)),
                      validator: (v) => v == null || v.isEmpty ? 'Select a mentor' : null,
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
                                : const Text('Save'),
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

class _CreateMilestoneDialog extends StatefulWidget {
  final ApiClient api;
  final String programId;

  const _CreateMilestoneDialog({required this.api, required this.programId});

  @override
  State<_CreateMilestoneDialog> createState() => _CreateMilestoneDialogState();
}

class _CreateMilestoneDialogState extends State<_CreateMilestoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _sortOrder = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.api.post('/admin/programs/${widget.programId}/milestones', body: {
        'title': _title.text.trim(),
        'sortOrder': int.parse(_sortOrder.text.trim()),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Create milestone failed', message: e.message);
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
              Text('Create milestone', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.flag_outlined)),
                validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrder,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sort order', prefixIcon: Icon(Icons.sort)),
                validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
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

class _CreateTaskDialog extends StatefulWidget {
  final ApiClient api;
  final String programId;
  final List<Map<String, dynamic>> milestones;

  const _CreateTaskDialog({required this.api, required this.programId, required this.milestones});

  @override
  State<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<_CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _links = TextEditingController();
  final _deadlineLabel = TextEditingController();

  String? _milestoneId;
  DateTime? _deadlineAtLocal;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _links.dispose();
    _deadlineLabel.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final initial = _deadlineAtLocal ?? now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (!mounted) return;
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => _deadlineAtLocal = combined);
    _deadlineLabel.text = MaterialLocalizations.of(context).formatFullDate(combined);
    _deadlineLabel.text += ' • ${time.format(context)}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final links = _links.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      final deadlineAt = _deadlineAtLocal;
      if (deadlineAt == null) {
        throw const ApiException('Deadline required');
      }

      await widget.api.post('/admin/programs/${widget.programId}/tasks', body: {
        'milestoneId': _milestoneId,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'deadlineAt': deadlineAt.toUtc().toIso8601String(),
        'resourceLinks': links,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Create task failed', message: e.message);
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Create task', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _milestoneId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('No milestone')),
                    ...widget.milestones.map(
                      (m) => DropdownMenuItem(value: m['id'] as String, child: Text(m['title']?.toString() ?? '')),
                    ),
                  ],
                  onChanged: (v) => setState(() => _milestoneId = v),
                  decoration: const InputDecoration(labelText: 'Milestone', prefixIcon: Icon(Icons.flag_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title', prefixIcon: Icon(Icons.task_outlined)),
                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _deadlineLabel,
                  readOnly: true,
                  onTap: _saving ? null : _pickDeadline,
                  decoration: InputDecoration(
                    labelText: 'Deadline',
                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                    suffixIcon: IconButton(
                      onPressed: _saving ? null : _pickDeadline,
                      icon: const Icon(Icons.access_time),
                      tooltip: 'Pick date & time',
                    ),
                  ),
                  validator: (_) => _deadlineAtLocal == null ? 'Deadline required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _links,
                  minLines: 2,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Resource links (one per line)',
                    prefixIcon: Icon(Icons.link),
                  ),
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
