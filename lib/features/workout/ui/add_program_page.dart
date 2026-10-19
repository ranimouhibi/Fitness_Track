import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/change_request_repository.dart';
import '../data/program_repository.dart';
import '../data/workout_repository.dart';

const _restLabel = 'Rest';

class _Pick {
  final sets = TextEditingController(text: '3');
  final reps = TextEditingController(text: '10');

  void dispose() {
    sets.dispose();
    reps.dispose();
  }
}

/// The form state for one day of the week.
class _DayForm {
  bool isRest = true;
  final Set<String> muscles = {};
  final Map<int, _Pick> picks = {};

  void clearPicks() {
    for (final p in picks.values) {
      p.dispose();
    }
    picks.clear();
  }

  void dispose() => clearPicks();

  /// Label saved for the day, in body-part order, e.g. "Chest + Back".
  String get label => muscleGroups.where(muscles.contains).join(' + ');
}

class AddProgramPage extends ConsumerStatefulWidget {
  /// Admin adds and edits apply right away. Others wait for approval.
  final bool isAdmin;

  /// Pre-selects the goal when opened from a goal page.
  final String? initialGoal;

  /// When set, the form edits this program instead of adding one.
  final Program? existing;

  const AddProgramPage({
    super.key,
    this.isAdmin = false,
    this.initialGoal,
    this.existing,
  });

  @override
  ConsumerState<AddProgramPage> createState() => _AddProgramPageState();
}

class _AddProgramPageState extends ConsumerState<AddProgramPage> {
  final _name = TextEditingController();
  final _weeks = TextEditingController(text: '8');
  final _minutes = TextEditingController(text: '60');
  final _description = TextEditingController();
  final _repo = ProgramRepository();
  final _changes = ChangeRequestRepository();

  late String _goal;
  String _intensity = 'medium';
  List<Exercise> _library = [];
  final List<_DayForm> _days = List.generate(7, (_) => _DayForm());
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _goal = e?.goal ?? widget.initialGoal ?? 'gain';
    if (e != null) {
      _name.text = e.name;
      _weeks.text = '${e.weeks}';
      _minutes.text = '${e.minutes}';
      _description.text = e.description ?? '';
      _intensity = e.intensity;
    }
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final items = await _repo.approvedExercises();
    if (!mounted) return;
    setState(() {
      _library = items;
      final e = widget.existing;
      if (e != null) _prefillDays(e);
    });
  }

  Exercise? _byName(String name) {
    for (final e in _library) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// Fills the form from an existing program, so it can be edited.
  void _prefillDays(Program p) {
    for (var i = 0; i < 7 && i < p.days.length; i++) {
      final src = p.days[i];
      final form = _days[i];
      if (src.isRest) continue;
      form.isRest = false;
      for (final m in (src.muscle ?? '').split(' + ')) {
        if (muscleGroups.contains(m)) form.muscles.add(m);
      }
      for (final line in src.exercises) {
        final match = _byName(line.name);
        if (match == null) continue;
        form.picks[match.id] = _Pick()
          ..sets.text = '${line.sets}'
          ..reps.text = '${line.reps}';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _weeks, _minutes, _description]) {
      c.dispose();
    }
    for (final d in _days) {
      d.dispose();
    }
    super.dispose();
  }

  void _setRest(int day) {
    setState(() {
      _days[day].clearPicks();
      _days[day].muscles.clear();
      _days[day].isRest = true;
    });
  }

  void _toggleMuscle(int day, String muscle, bool on) {
    setState(() {
      final form = _days[day];
      if (on) {
        form.muscles.add(muscle);
        form.isRest = false;
      } else {
        form.muscles.remove(muscle);
        // Drop the picked exercises that belonged to this muscle.
        for (final e in _library.where((e) => e.muscleGroup == muscle)) {
          form.picks.remove(e.id)?.dispose();
        }
        if (form.muscles.isEmpty) form.isRest = true;
      }
    });
  }

  void _togglePick(int day, Exercise e, bool on) {
    setState(() {
      final picks = _days[day].picks;
      if (on) {
        picks[e.id] = _Pick();
      } else {
        picks.remove(e.id)?.dispose();
      }
    });
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _submit() async {
    final nameError = Validators.requiredText(_name.text, 'the program name');
    if (nameError != null) {
      _fail(nameError);
      return;
    }
    final weeksError = Validators.intInRange(_weeks.text, 'Weeks', 1, 52);
    if (weeksError != null) {
      _fail(weeksError);
      return;
    }
    final minutesError = Validators.intInRange(
        _minutes.text, 'Minutes per session', 10, 240);
    if (minutesError != null) {
      _fail(minutesError);
      return;
    }
    final weeks = int.parse(_weeks.text.trim());
    final minutes = int.parse(_minutes.text.trim());

    final plan = <DayPlan>[];
    for (var i = 0; i < 7; i++) {
      final d = _days[i];
      if (d.isRest) {
        plan.add(DayPlan.rest());
        continue;
      }
      if (d.picks.isEmpty) {
        _fail('Choose exercises for ${weekdayNames[i]}, or set it to Rest.');
        return;
      }
      final exercises = <({int exerciseId, int sets, int reps})>[];
      for (final entry in d.picks.entries) {
        final setsError = Validators.intInRange(
            entry.value.sets.text, 'Sets (${weekdayNames[i]})', 1, 20);
        if (setsError != null) {
          _fail(setsError);
          return;
        }
        final repsError = Validators.intInRange(
            entry.value.reps.text, 'Reps (${weekdayNames[i]})', 1, 100);
        if (repsError != null) {
          _fail(repsError);
          return;
        }
        exercises.add((
          exerciseId: entry.key,
          sets: int.parse(entry.value.sets.text.trim()),
          reps: int.parse(entry.value.reps.text.trim()),
        ));
      }
      plan.add(DayPlan.train(d.label, exercises));
    }

    if (plan.every((d) => d.isRest)) {
      _fail('Add at least one training day.');
      return;
    }

    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = programPayload(
      name: _name.text,
      goal: _goal,
      intensity: _intensity,
      weeks: weeks,
      minutes: minutes,
      description: _description.text,
      days: plan,
    );

    final existing = widget.existing;
    if (existing != null && widget.isAdmin) {
      await _repo.updateProgram(existing.id, payload);
    } else if (existing != null) {
      await _changes.submit(
        type: 'edit',
        table: 'programs',
        targetId: existing.id,
        userId: user.id,
        payload: {...payload, 'target_name': existing.name},
      );
    } else {
      await _repo.addProgram(
        payload: payload,
        userId: user.id,
        isAdmin: widget.isAdmin,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final title = editing
        ? 'Edit program'
        : (widget.isAdmin ? 'Add program' : 'Add a program');
    final buttonLabel = widget.isAdmin
        ? 'Save'
        : (editing ? 'Send edit to admin' : 'Submit to admin');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.isAdmin)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Reviewed by an admin before it appears in the app.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: _decoration('Program name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: _decoration('Goal'),
            items: [
              for (final g in goals.entries)
                DropdownMenuItem(value: g.key, child: Text(g.value)),
            ],
            onChanged: (v) => setState(() => _goal = v ?? _goal),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _intensity,
            decoration: _decoration('Intensity'),
            items: [
              for (final i in intensities.entries)
                DropdownMenuItem(value: i.key, child: Text(i.value)),
            ],
            onChanged: (v) => setState(() => _intensity = v ?? _intensity),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _numField('Weeks (1-52)', _weeks)),
            const SizedBox(width: 12),
            Expanded(child: _numField('Minutes (10-240)', _minutes)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 300,
            decoration: _decoration('Description'),
          ),
          const SizedBox(height: 24),
          const Text('Weekly plan',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBlue)),
          const SizedBox(height: 4),
          const Text('Choose one or more muscles for each day, or Rest.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          for (var i = 0; i < 7; i++) _dayCard(i),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(int day) {
    final form = _days[day];
    final exercises = form.isRest
        ? <Exercise>[]
        : _library.where((e) => form.muscles.contains(e.muscleGroup)).toList();

    final body = <Widget>[];
    if (form.isRest) {
      body.add(const Text('Rest day',
          style: TextStyle(color: AppColors.textSecondary)));
    } else if (exercises.isEmpty) {
      body.add(const Text(
        'No approved exercises for these muscles yet. Add some in Exercises first.',
        style: TextStyle(color: AppColors.textSecondary),
      ));
    } else {
      for (final e in exercises) {
        body.add(_exerciseRow(day, e));
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(weekdayNames[day],
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text(_restLabel),
                  selected: form.isRest,
                  onSelected: (_) => _setRest(day),
                ),
                for (final g in muscleGroups)
                  FilterChip(
                    label: Text(g),
                    selected: form.muscles.contains(g),
                    onSelected: (on) => _toggleMuscle(day, g, on),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ...body,
          ],
        ),
      ),
    );
  }

  Widget _exerciseRow(int day, Exercise e) {
    final pick = _days[day].picks[e.id];
    return Column(
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: pick != null,
          onChanged: (v) => _togglePick(day, e, v ?? false),
          title: Text(e.name),
          subtitle: Text('${e.muscleGroup} · ${e.equipment ?? ''}'),
        ),
        if (pick != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: _numField('Sets (1-20)', pick.sets)),
              const SizedBox(width: 12),
              Expanded(child: _numField('Reps (1-100)', pick.reps)),
            ]),
          ),
      ],
    );
  }

  Widget _numField(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: _decoration(label),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}