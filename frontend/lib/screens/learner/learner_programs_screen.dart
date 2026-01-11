import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../ui/app_popups.dart';

class LearnerProgramsScreen extends StatefulWidget {
  final ApiClient api;
  final void Function(String programId) openProgram;

  const LearnerProgramsScreen({
    super.key,
    required this.api,
    required this.openProgram,
  });

  @override
  State<LearnerProgramsScreen> createState() => _LearnerProgramsScreenState();
}

class _LearnerProgramsScreenState extends State<LearnerProgramsScreen> {
  static const _pageSize = 20;

  // Enrolled programs
  bool _loadingEnrolled = true;
  bool _loadingMoreEnrolled = false;
  bool _hasMoreEnrolled = true;
  int _offsetEnrolled = 0;
  final List<Map<String, dynamic>> _enrolled = [];

  // Available programs (not enrolled)
  bool _loadingAvailable = false;
  bool _loadingMoreAvailable = false;
  bool _hasMoreAvailable = true;
  int _offsetAvailable = 0;
  final List<Map<String, dynamic>> _available = [];

  final Set<String> _enrolling = {};

  @override
  void initState() {
    super.initState();
    _loadEnrolled(reset: true);
  }

  Future<void> _loadEnrolled({required bool reset}) async {
    if (_loadingMoreEnrolled) return;
    if (!reset && !_hasMoreEnrolled) return;

    setState(() {
      if (reset) {
        _loadingEnrolled = true;
      } else {
        _loadingMoreEnrolled = true;
      }
    });

    try {
      final nextOffset = reset ? 0 : _offsetEnrolled;
      final json = await widget.api.get(
        '/learner/programs',
        query: {
          'limit': '$_pageSize',
          'offset': '$nextOffset',
        },
      );
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _enrolled.clear();
        _enrolled.addAll(items);
        _offsetEnrolled = nextOffset + items.length;
        _hasMoreEnrolled = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load programs', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loadingEnrolled = false;
          _loadingMoreEnrolled = false;
        });
      }
    }
  }

  Future<void> _loadAvailable({required bool reset}) async {
    if (_loadingMoreAvailable) return;
    if (!reset && !_hasMoreAvailable) return;

    setState(() {
      if (reset) {
        _loadingAvailable = true;
      } else {
        _loadingMoreAvailable = true;
      }
    });

    try {
      final nextOffset = reset ? 0 : _offsetAvailable;
      final json = await widget.api.get(
        '/learner/programs/available',
        query: {
          'limit': '$_pageSize',
          'offset': '$nextOffset',
        },
      );
      final items = ((json as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();

      setState(() {
        if (reset) _available.clear();
        _available.addAll(items);
        _offsetAvailable = nextOffset + items.length;
        _hasMoreAvailable = items.length == _pageSize;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Failed to load available programs', message: e.message);
    } finally {
      if (mounted) {
        setState(() {
          _loadingAvailable = false;
          _loadingMoreAvailable = false;
        });
      }
    }
  }

  Future<void> _enroll(String programId) async {
    if (_enrolling.contains(programId)) return;
    setState(() => _enrolling.add(programId));
    try {
      await widget.api.post('/learner/programs/$programId/enroll');
      if (!mounted) return;
      await showAppInfoPopup(
        context,
        title: 'Enrolled',
        message: 'You are now enrolled in this program.',
      );
      await _loadEnrolled(reset: true);
      await _loadAvailable(reset: true);
    } on ApiException catch (e) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Enroll failed', message: e.message);
    } catch (_) {
      if (!mounted) return;
      await showAppErrorPopup(context, title: 'Enroll failed', message: 'Something went wrong.');
    } finally {
      if (mounted) setState(() => _enrolling.remove(programId));
    }
  }

  Widget _buildEnrolledTab() {
    if (_loadingEnrolled) return const Center(child: CircularProgressIndicator());
    if (_enrolled.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 40),
          Center(child: Text('No enrolled programs yet.')),
          SizedBox(height: 8),
          Center(child: Text('Switch to Available to enroll.')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadEnrolled(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _enrolled.length + (_hasMoreEnrolled ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == _enrolled.length) {
            if (!_loadingMoreEnrolled) {
              _loadEnrolled(reset: false);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final p = _enrolled[i];
          return ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(p['title']?.toString() ?? ''),
            subtitle: Text(p['description']?.toString() ?? ''),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => widget.openProgram(p['id'] as String),
          );
        },
      ),
    );
  }

  Widget _buildAvailableTab() {
    if (_loadingAvailable) return const Center(child: CircularProgressIndicator());
    if (_available.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadAvailable(reset: true),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SizedBox(height: 40),
            Center(child: Text('No available programs right now.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAvailable(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _available.length + (_hasMoreAvailable ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          if (i == _available.length) {
            if (!_loadingMoreAvailable) {
              _loadAvailable(reset: false);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final p = _available[i];
          final programId = p['id'] as String;
          final enrolling = _enrolling.contains(programId);
          final mentorName = (p['mentor_name'] ?? p['mentorName'])?.toString();

          return ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Text(p['title']?.toString() ?? ''),
            subtitle: Text(
              [
                if ((p['description']?.toString() ?? '').isNotEmpty) p['description']?.toString() ?? '',
                if (mentorName != null && mentorName.isNotEmpty) 'Mentor: $mentorName',
              ].where((e) => e.isNotEmpty).join('\n'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            onTap: () async {
              await showAppInfoPopup(
                context,
                title: 'Enroll to view',
                message: 'Enroll in this program to view tasks and milestones.',
              );
            },
            trailing: FilledButton(
              onPressed: enrolling ? null : () => _enroll(programId),
              child: enrolling
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enroll'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Programs'),
          bottom: TabBar(
            onTap: (index) {
              // Lazy-load Available tab to minimize API calls.
              if (index == 1 && _available.isEmpty && !_loadingAvailable) {
                _loadAvailable(reset: true);
              }
            },
            tabs: const [
              Tab(text: 'My Programs'),
              Tab(text: 'Available'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildEnrolledTab(),
            _buildAvailableTab(),
          ],
        ),
      ),
    );
  }
}
