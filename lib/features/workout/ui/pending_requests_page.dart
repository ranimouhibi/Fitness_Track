import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/change_request_repository.dart';
import '../data/program_repository.dart';
import '../data/workout_repository.dart';

/// One item waiting for the admin. Exercises and programs share this shape.
class PendingItem {
  final String title;
  final String kindLabel;
  final String category; // 'exercise' or 'program'
  final String submitter;
  final List<(String, String)> lines;
  final String? description;
  final List<String> steps;
  final List<String> days;
  final Future<void> Function(bool accept) decide;

  const PendingItem({
    required this.title,
    required this.kindLabel,
    required this.category,
    required this.submitter,
    required this.lines,
    this.description,
    this.steps = const <String>[],
    this.days = const <String>[],
    required this.decide,
  });
}

class PendingRequestsPage extends ConsumerStatefulWidget {
  /// 'exercise' or 'program' shows only that kind. Null shows everything.
  final String? category;

  const PendingRequestsPage({super.key, this.category});

  @override
  ConsumerState<PendingRequestsPage> createState() =>
      _PendingRequestsPageState();
}

class _PendingRequestsPageState extends ConsumerState<PendingRequestsPage> {
  List<PendingItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _title {
    switch (widget.category) {
      case 'exercise':
        return 'Pending exercises';
      case 'program':
        return 'Pending programs';
      default:
        return 'Pending requests';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _build();
    final items = widget.category == null
        ? all
        : all.where((i) => i.category == widget.category).toList();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<List<PendingItem>> _build() async {
    final adminId = ref.read(sessionProvider)?.id ?? 0;
    final items = <PendingItem>[];

    // New exercises waiting for approval.
    final workout = WorkoutRepository();
    for (final (e, who) in await workout.pendingExercises()) {
      items.add(PendingItem(
        title: e.name,
        kindLabel: 'New exercise',
        category: 'exercise',
        submitter: who,
        lines: [
          ('Muscle', e.muscleGroup),
          ('Equipment', e.equipment ?? '-'),
        ],
        description: e.description,
        steps: e.steps,
        decide: (accept) =>
            workout.setExerciseStatus(e.id, accept ? 'approved' : 'refused'),
      ));
    }

    // New programs waiting for approval.
    final programs = ProgramRepository();
    for (final (p, who) in await programs.pendingPrograms()) {
      items.add(PendingItem(
        title: p.name,
        kindLabel: 'New program',
        category: 'program',
        submitter: who,
        lines: [
          ('Goal', goals[p.goal] ?? p.goal),
          ('Intensity', intensities[p.intensity] ?? p.intensity),
          ('Weeks', '${p.weeks}'),
          ('Minutes', '${p.minutes}'),
        ],
        description: p.description,
        days: [
          for (final d in p.days)
            '${d.weekday}: ${d.isRest ? 'Rest' : d.muscle}',
        ],
        decide: (accept) =>
            programs.setProgramStatus(p.id, accept ? 'approved' : 'refused'),
      ));
    }

    // Edit and delete requests from users and coaches.
    final changes = ChangeRequestRepository();
    for (final c in await changes.pending()) {
      final isDelete = c.type == 'delete';
      final isExercise = c.targetTable == 'exercises';
      final category = isExercise ? 'exercise' : 'program';
      final kind =
          '${isDelete ? 'Delete' : 'Edit'} ${isExercise ? 'exercise' : 'program'}';
      final targetName =
          (c.payload['target_name'] ?? 'item #${c.targetId}').toString();
      items.add(PendingItem(
        title: targetName,
        kindLabel: kind,
        category: category,
        submitter: c.submitterName,
        lines: isDelete ? <(String, String)>[] : _changeLines(c),
        description: isDelete ? null : c.payload['description'] as String?,
        steps: (!isDelete && isExercise)
            ? _steps(c.payload['instructions'] as String?)
            : const <String>[],
        days: (!isDelete && !isExercise)
            ? _dayLines(c.payload)
            : const <String>[],
        decide: (accept) => changes.decide(c, accept: accept, adminId: adminId),
      ));
    }

    return items;
  }

  List<(String, String)> _changeLines(ChangeRequest c) {
    final p = c.payload;
    if (c.targetTable == 'exercises') {
      return [
        ('Name', '${p['name'] ?? ''}'),
        ('Muscle', '${p['muscle_group'] ?? ''}'),
        ('Equipment', '${p['equipment'] ?? '-'}'),
      ];
    }
    return [
      ('Name', '${p['name'] ?? ''}'),
      ('Goal', goals['${p['goal']}'] ?? '${p['goal']}'),
      ('Intensity', intensities['${p['intensity']}'] ?? '${p['intensity']}'),
      ('Weeks', '${p['weeks'] ?? ''}'),
      ('Minutes', '${p['minutes'] ?? ''}'),
    ];
  }

  List<String> _steps(String? text) => (text ?? '')
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  List<String> _dayLines(Map<String, dynamic> p) {
    final days = (p['days'] as List?) ?? const [];
    return [
      for (var i = 0; i < days.length && i < 7; i++)
        _dayText(i, days[i] as Map),
    ];
  }

  String _dayText(int index, Map d) {
    final label = d['isRest'] == true ? 'Rest' : '${d['title']}';
    return '${weekdayNames[index]}: $label';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('No pending requests.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return _PendingCard(
                        item: item,
                        onTap: () async {
                          final done = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => _PendingDetail(item: item),
                            ),
                          );
                          if (done == true) await _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final PendingItem item;
  final VoidCallback onTap;

  const _PendingCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(item.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('by ${item.submitter}'),
        trailing: Chip(
          label: Text(item.kindLabel, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}

class _PendingDetail extends StatefulWidget {
  final PendingItem item;
  const _PendingDetail({required this.item});

  @override
  State<_PendingDetail> createState() => _PendingDetailState();
}

class _PendingDetailState extends State<_PendingDetail> {
  bool _busy = false;

  Future<void> _decide(bool accept) async {
    setState(() => _busy = true);
    try {
      await widget.item.decide(accept);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Could not apply this change. A deleted exercise may still be used in a program.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final description = item.description ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(item.kindLabel)),
              Chip(
                avatar: const Icon(Icons.person_outline, size: 16),
                label: Text(item.submitter),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final (label, value) in item.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(label,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Title('Description'),
            Text(description, style: const TextStyle(height: 1.4)),
          ],
          if (item.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Title('Instructions'),
            for (var i = 0; i < item.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${item.steps[i]}'),
              ),
          ],
          if (item.days.isNotEmpty) ...[
            const SizedBox(height: 12),
            const _Title('Weekly plan'),
            for (final d in item.days)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(d),
              ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _decide(false),
                  child: const Text('Refuse'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _decide(true),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBlue)),
    );
  }
}