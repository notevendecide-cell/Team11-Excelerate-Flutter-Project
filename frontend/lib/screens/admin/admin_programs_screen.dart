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
  final ScrollController _scrollController = ScrollController();

  bool _loadingMentors = true;
  bool _saving = false;
  List<Map<String, dynamic>> _mentors = const [];
  String? _mentorId;

  final List<_ModuleDraft> _modules = [
    _ModuleDraft(
      title: TextEditingController(text: 'Module 1'),
      sortOrder: TextEditingController(text: '0'),
      chapters: [
        _ModuleChapterDraft(
          title: TextEditingController(text: 'Chapter 1'),
          sortOrder: TextEditingController(text: '0'),
          bodyMd: TextEditingController(text: '## Welcome\n\nWrite your module content in **Markdown** here.'),
        ),
      ],
      items: [
        _ModuleItemDraft(
          title: TextEditingController(text: 'Deliverable 1'),
          description: TextEditingController(),
          links: TextEditingController(),
          deadlineLabel: TextEditingController(),
          deadlineAtLocal: null,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadMentors();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _scrollController.dispose();
    for (final m in _modules) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline(_ModuleItemDraft item) async {
    final now = DateTime.now();
    final initial = item.deadlineAtLocal ?? now.add(const Duration(days: 7));

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
    setState(() {
      item.deadlineAtLocal = combined;
      item.deadlineLabel.text = MaterialLocalizations.of(context).formatFullDate(combined);
      item.deadlineLabel.text += ' • ${time.format(context)}';
    });
  }

  void _addModule() {
    setState(() {
      _modules.add(
        _ModuleDraft(
          title: TextEditingController(text: 'Module ${_modules.length + 1}'),
          sortOrder: TextEditingController(text: '${_modules.length}'),
          chapters: [
            _ModuleChapterDraft(
              title: TextEditingController(text: 'Chapter 1'),
              sortOrder: TextEditingController(text: '0'),
              bodyMd: TextEditingController(text: '## Chapter 1\n\nAdd content here...'),
            ),
          ],
          items: [
            _ModuleItemDraft(
              title: TextEditingController(text: 'Deliverable 1'),
              description: TextEditingController(),
              links: TextEditingController(),
              deadlineLabel: TextEditingController(),
              deadlineAtLocal: null,
            ),
          ],
        ),
      );
    });
  }

  void _removeModule(int index) {
    if (_modules.length <= 1) return;
    setState(() {
      final removed = _modules.removeAt(index);
      removed.dispose();
    });
  }

  void _addChapter(int moduleIndex) {
    setState(() {
      final m = _modules[moduleIndex];
      m.chapters.add(
        _ModuleChapterDraft(
          title: TextEditingController(text: 'Chapter ${m.chapters.length + 1}'),
          sortOrder: TextEditingController(text: '${m.chapters.length}'),
          bodyMd: TextEditingController(text: '## Chapter ${m.chapters.length + 1}\n\nAdd content here...'),
        ),
      );
    });
  }

  void _removeChapter(int moduleIndex, int chapterIndex) {
    setState(() {
      final removed = _modules[moduleIndex].chapters.removeAt(chapterIndex);
      removed.dispose();
    });
  }

  void _addItem(int moduleIndex) {
    setState(() {
      _modules[moduleIndex].items.add(
            _ModuleItemDraft(
              title: TextEditingController(text: 'Deliverable ${_modules[moduleIndex].items.length + 1}'),
              description: TextEditingController(),
              links: TextEditingController(),
              deadlineLabel: TextEditingController(),
              deadlineAtLocal: null,
            ),
          );
    });
  }

  void _removeItem(int moduleIndex, int itemIndex) {
    setState(() {
      final removed = _modules[moduleIndex].items.removeAt(itemIndex);
      removed.dispose();
    });
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

    // Validate module builder.
    if (_modules.isEmpty) {
      await showAppErrorPopup(context, title: 'Missing modules', message: 'Add at least one module.');
      return;
    }
    for (final m in _modules) {
      if (m.title.text.trim().length < 2) {
        await showAppErrorPopup(context, title: 'Invalid module', message: 'Each module must have a title.');
        return;
      }
      for (final ch in m.chapters) {
        if (ch.title.text.trim().length < 2) {
          await showAppErrorPopup(context, title: 'Invalid chapter', message: 'Each chapter must have a title.');
          return;
        }
        if (ch.bodyMd.text.trim().isEmpty) {
          await showAppErrorPopup(context, title: 'Missing chapter content', message: 'Each chapter needs content (Markdown).');
          return;
        }
      }
      for (final item in m.items) {
        if (item.title.text.trim().length < 2) {
          await showAppErrorPopup(context, title: 'Invalid deliverable', message: 'Each deliverable must have a title.');
          return;
        }
        if (item.deadlineAtLocal == null) {
          await showAppErrorPopup(context, title: 'Missing deadline', message: 'Each deliverable must have a deadline.');
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final modulesPayload = _modules
          .map(
            (m) => {
              'title': m.title.text.trim(),
              'sortOrder': int.tryParse(m.sortOrder.text.trim()) ?? 0,
              'chapters': m.chapters
                  .map(
                    (c) => {
                      'title': c.title.text.trim(),
                      'sortOrder': int.tryParse(c.sortOrder.text.trim()) ?? 0,
                      'bodyMd': c.bodyMd.text,
                    },
                  )
                  .toList(growable: false),
              'items': m.items
                  .map(
                    (i) => {
                      'title': i.title.text.trim(),
                      'description': i.description.text.trim(),
                      'deadlineAt': i.deadlineAtLocal!.toUtc().toIso8601String(),
                      'resourceLinks': i.links.text
                          .split('\n')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList(growable: false),
                    },
                  )
                  .toList(growable: false),
            },
          )
          .toList(growable: false);

      await widget.api.post('/admin/programs/with-structure', body: {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'mentorId': _mentorId,
        'modules': modulesPayload,
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    final insets = MediaQuery.viewInsetsOf(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets.bottom),
      child: Dialog(
        insetPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
          child: _loadingMentors
              ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Column(
                    children: [
                      Expanded(
                        child: Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(20),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    prefixIcon: Icon(Icons.school_outlined),
                                  ),
                                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter a title' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _description,
                                  minLines: 3,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    prefixIcon: Icon(Icons.description_outlined),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('Modules', style: Theme.of(context).textTheme.titleMedium),
                                    ),
                                    IconButton(
                                      tooltip: 'Add module',
                                      onPressed: _saving ? null : _addModule,
                                      icon: const Icon(Icons.add_circle_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._modules.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final m = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Card(
                                      elevation: 0,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller: m.title,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Module title',
                                                      prefixIcon: Icon(Icons.view_module_outlined),
                                                    ),
                                                    validator: (v) => (v ?? '').trim().length < 2 ? 'Enter module title' : null,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                SizedBox(
                                                  width: 110,
                                                  child: TextFormField(
                                                    controller: m.sortOrder,
                                                    keyboardType: TextInputType.number,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Order',
                                                      prefixIcon: Icon(Icons.sort),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  tooltip: _modules.length <= 1
                                                      ? 'At least one module required'
                                                      : 'Remove module',
                                                  onPressed: (_saving || _modules.length <= 1) ? null : () => _removeModule(idx),
                                                  icon: const Icon(Icons.delete_outline),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text('Chapters', style: Theme.of(context).textTheme.titleSmall),
                                                ),
                                                IconButton(
                                                  tooltip: 'Add chapter',
                                                  onPressed: _saving ? null : () => _addChapter(idx),
                                                  icon: const Icon(Icons.add),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            if (m.chapters.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.only(bottom: 10),
                                                child: Text('No chapters (optional).'),
                                              )
                                            else
                                              ...m.chapters.asMap().entries.map((chEntry) {
                                                final chapterIndex = chEntry.key;
                                                final ch = chEntry.value;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: Card(
                                                    elevation: 0,
                                                    color: Theme.of(context).colorScheme.surface,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(12),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: TextFormField(
                                                                  controller: ch.title,
                                                                  decoration: const InputDecoration(
                                                                    labelText: 'Chapter title',
                                                                    prefixIcon: Icon(Icons.article_outlined),
                                                                  ),
                                                                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter title' : null,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 10),
                                                              SizedBox(
                                                                width: 110,
                                                                child: TextFormField(
                                                                  controller: ch.sortOrder,
                                                                  keyboardType: TextInputType.number,
                                                                  decoration: const InputDecoration(
                                                                    labelText: 'Order',
                                                                    prefixIcon: Icon(Icons.sort),
                                                                  ),
                                                                ),
                                                              ),
                                                              IconButton(
                                                                tooltip: 'Remove chapter',
                                                                onPressed: _saving ? null : () => _removeChapter(idx, chapterIndex),
                                                                icon: const Icon(Icons.delete_outline),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 10),
                                                          TextFormField(
                                                            controller: ch.bodyMd,
                                                            minLines: 4,
                                                            maxLines: 10,
                                                            decoration: const InputDecoration(
                                                              labelText: 'Chapter content (Markdown)',
                                                              alignLabelWithHint: true,
                                                              hintText: 'Example:\n# Heading\n\n- Bullet\n- Bullet\n\n**bold** text',
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text('Deliverables', style: Theme.of(context).textTheme.titleSmall),
                                                ),
                                                IconButton(
                                                  tooltip: 'Add deliverable',
                                                  onPressed: _saving ? null : () => _addItem(idx),
                                                  icon: const Icon(Icons.add),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            if (m.items.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.only(bottom: 10),
                                                child: Text('No deliverables (no submission required).'),
                                              )
                                            else
                                              ...m.items.asMap().entries.map((it) {
                                                final itemIndex = it.key;
                                                final item = it.value;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: Card(
                                                    elevation: 0,
                                                    color: Theme.of(context).colorScheme.surface,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(12),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Expanded(
                                                                child: TextFormField(
                                                                  controller: item.title,
                                                                  decoration: const InputDecoration(
                                                                    labelText: 'Deliverable title',
                                                                    prefixIcon: Icon(Icons.task_outlined),
                                                                  ),
                                                                  validator: (v) => (v ?? '').trim().length < 2 ? 'Enter title' : null,
                                                                ),
                                                              ),
                                                              IconButton(
                                                                tooltip: 'Remove deliverable',
                                                                onPressed: _saving ? null : () => _removeItem(idx, itemIndex),
                                                                icon: const Icon(Icons.delete_outline),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 10),
                                                          TextFormField(
                                                            controller: item.deadlineLabel,
                                                            readOnly: true,
                                                            onTap: _saving ? null : () => _pickDeadline(item),
                                                            decoration: InputDecoration(
                                                              labelText: 'Deadline',
                                                              prefixIcon: const Icon(Icons.calendar_month_outlined),
                                                              suffixIcon: IconButton(
                                                                onPressed: _saving ? null : () => _pickDeadline(item),
                                                                icon: const Icon(Icons.access_time),
                                                                tooltip: 'Pick date & time',
                                                              ),
                                                            ),
                                                            validator: (_) => item.deadlineAtLocal == null ? 'Deadline required' : null,
                                                          ),
                                                          const SizedBox(height: 10),
                                                          TextFormField(
                                                            controller: item.description,
                                                            minLines: 2,
                                                            maxLines: 4,
                                                            decoration: const InputDecoration(
                                                              labelText: 'Description',
                                                              prefixIcon: Icon(Icons.description_outlined),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 10),
                                                          TextFormField(
                                                            controller: item.links,
                                                            minLines: 1,
                                                            maxLines: 4,
                                                            decoration: const InputDecoration(
                                                              labelText: 'Resource links (one per line)',
                                                              prefixIcon: Icon(Icons.link),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                const SizedBox(height: 28),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving ? null : _save,
                                  child: _saving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Create'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ModuleDraft {
  final TextEditingController title;
  final TextEditingController sortOrder;
  final List<_ModuleChapterDraft> chapters;
  final List<_ModuleItemDraft> items;

  _ModuleDraft({required this.title, required this.sortOrder, required this.chapters, required this.items});

  void dispose() {
    title.dispose();
    sortOrder.dispose();
    for (final c in chapters) {
      c.dispose();
    }
    for (final i in items) {
      i.dispose();
    }
  }
}

class _ModuleChapterDraft {
  final TextEditingController title;
  final TextEditingController sortOrder;
  final TextEditingController bodyMd;

  _ModuleChapterDraft({required this.title, required this.sortOrder, required this.bodyMd});

  void dispose() {
    title.dispose();
    sortOrder.dispose();
    bodyMd.dispose();
  }
}

class _ModuleItemDraft {
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController links;
  final TextEditingController deadlineLabel;
  DateTime? deadlineAtLocal;

  _ModuleItemDraft({
    required this.title,
    required this.description,
    required this.links,
    required this.deadlineLabel,
    required this.deadlineAtLocal,
  });

  void dispose() {
    title.dispose();
    description.dispose();
    links.dispose();
    deadlineLabel.dispose();
  }
}
