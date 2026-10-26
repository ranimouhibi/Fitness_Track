import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/program_repository.dart';
import '../data/progress_repository.dart';
import 'add_program_page.dart';
import 'widgets/training_style.dart';

/// Gradient app bar used on the progress pages.
PreferredSizeWidget trainAppBar(String title) => AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      foregroundColor: Colors.white,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: TrainStyle.hero),
      ),
    );

InputDecoration progressField(String label, {String? suffix}) => InputDecoration(
      labelText: label,
      suffixText: suffix,
      isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

double? parseNumber(String text) =>
    double.tryParse(text.trim().replaceAll(',', '.'));

Widget _errorText(String? message) => message == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(message, style: const TextStyle(color: Colors.red)),
      );

Widget _partField(String part, TextEditingController c) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: progressField(part, suffix: 'cm'),
      ),
    );

// ---------------------------------------------------------------------------
// Edit weight, height and body measures
// ---------------------------------------------------------------------------

class ProfileEditPage extends StatefulWidget {
  final ProfileData profile;
  const ProfileEditPage({super.key, required this.profile});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _repo = ProgressRepository();
  late final TextEditingController _weight;
  late final TextEditingController _height;
  final Map<String, TextEditingController> _parts = {};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _weight = TextEditingController(
        text: p.weightKg == null ? '' : p.weightKg!.toStringAsFixed(1));
    _height = TextEditingController(
        text: p.heightCm == null ? '' : p.heightCm!.toStringAsFixed(0));
    for (final part in bodyParts) {
      final v = p.measures[part];
      _parts[part] =
          TextEditingController(text: v == null ? '' : v.toStringAsFixed(1));
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _height.dispose();
    for (final c in _parts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final weight = parseNumber(_weight.text);
    final height = parseNumber(_height.text);
    if (weight == null || weight < 30 || weight > 300) {
      setState(() => _error = 'Weight must be between 30 and 300 kg.');
      return;
    }
    if (height == null || height < 100 || height > 250) {
      setState(() => _error = 'Height must be between 100 and 250 cm.');
      return;
    }
    final measures = <String, double?>{};
    for (final e in _parts.entries) {
      final text = e.value.text.trim();
      if (text.isEmpty) {
        measures[e.key] = null;
        continue;
      }
      final v = parseNumber(text);
      if (v == null || v < 5 || v > 200) {
        setState(() => _error = '${e.key} must be between 5 and 200 cm.');
        return;
      }
      measures[e.key] = v;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await _repo.updateProfile(
      userId: widget.profile.id,
      weight: weight,
      height: height,
      measures: measures,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TrainStyle.pageBg,
      appBar: trainAppBar('My measurements'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'Weight in kilograms, everything else in centimetres. Leave a body part empty to remove it.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: progressField('Weight', suffix: 'kg'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: progressField('Height', suffix: 'cm'),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          const TrainSectionTitle('Body parts'),
          for (final part in bodyParts) _partField(part, _parts[part]!),
          _errorText(_error),
          TrainButton(
            label: _saving ? 'Saving...' : 'Save measurements',
            icon: Icons.check,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start a progress plan
// ---------------------------------------------------------------------------

class StartProgressPage extends StatefulWidget {
  final int userId;
  const StartProgressPage({super.key, required this.userId});

  @override
  State<StartProgressPage> createState() => _StartProgressPageState();
}

class _StartProgressPageState extends State<StartProgressPage> {
  final _repo = ProgressRepository();
  final _programRepo = ProgramRepository();
  final _weeks = TextEditingController(text: '12');
  final _target = TextEditingController();
  String _objective = objectives.first;
  bool _ownMode = false;
  List<Program> _approved = [];
  int? _existingProgramId;
  Program? _ownProgram;
  ProfileData? _profile;
  String? _error;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _repo.profile(widget.userId);
    final programs = await _programRepo.approvedPrograms();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _approved = programs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _weeks.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Only Lose weight and Gain muscle use a target weight.
  bool get _usesTarget =>
      _objective == 'Lose weight' || _objective == 'Gain muscle';

  Future<void> _createOwn() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddProgramPage(isPrivate: true)),
    );
    if (created != true) return;
    final program = await _programRepo.latestPrivateProgram(widget.userId);
    if (!mounted) return;
    setState(() {
      _ownProgram = program;
      _ownMode = true;
    });
  }

  /// Checks the target against the current weight for the chosen objective.
  /// Returns an error message, or null when the target is valid.
  String? _checkTarget(double current, double target) {
    if (_objective == 'Lose weight' && target >= current) {
      return 'For Lose weight, the target must be lower than your current '
          'weight (${current.toStringAsFixed(1)} kg).';
    }
    if (_objective == 'Gain muscle' && target <= current) {
      return 'For Gain muscle, the target must be higher than your current '
          'weight (${current.toStringAsFixed(1)} kg).';
    }
    return null;
  }

  Future<void> _start() async {
    if (_saving || _profile == null) return;
    final weeks = int.tryParse(_weeks.text.trim());
    if (weeks == null || weeks < 1 || weeks > 52) {
      setState(() => _error = 'Duration must be between 1 and 52 weeks.');
      return;
    }

    final current = _profile!.weightKg;
    double? target;
    if (_usesTarget) {
      target = parseNumber(_target.text);
      if (target == null || target < 30 || target > 300) {
        setState(() => _error = 'Enter a target weight between 30 and 300 kg.');
        return;
      }
      if (current == null) {
        setState(() => _error =
            'Set your current weight in your measurements first.');
        return;
      }
      final problem = _checkTarget(current, target);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
    }

    final programId = _ownMode ? _ownProgram?.id : _existingProgramId;
    if (programId == null) {
      setState(() => _error = 'Choose an existing program or create your own.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final p = _profile!;
    await _repo.startPlan(
      userId: widget.userId,
      objective: _objective,
      weeks: weeks,
      programId: programId,
      startWeight: p.weightKg,
      targetWeight: target,
      baseline: p.measures,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: trainAppBar('Start progress'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final current = _profile?.weightKg;
    return Scaffold(
      backgroundColor: TrainStyle.pageBg,
      appBar: trainAppBar('Start progress'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const TrainSectionTitle('Objective'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in objectives)
                TrainChoice(
                  label: o,
                  selected: _objective == o,
                  onTap: () => setState(() {
                    _objective = o;
                    _error = null;
                  }),
                ),
            ],
          ),
          if (_usesTarget) ...[
            const SizedBox(height: 14),
            TrainCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  Expanded(
                    child: _weightLabel(
                      'Current weight',
                      current == null
                          ? '--'
                          : '${current.toStringAsFixed(1)} kg',
                    ),
                  ),
                  Expanded(
                    child: _weightLabel(
                      'Target weight',
                      _targetPreview(current),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: progressField(
                _objective == 'Lose weight'
                    ? 'Target weight (lower than current)'
                    : 'Target weight (higher than current)',
                suffix: 'kg',
              ),
            ),
          ],
          const TrainSectionTitle('Duration'),
          TextField(
            controller: _weeks,
            keyboardType: TextInputType.number,
            decoration: progressField('Duration', suffix: 'weeks'),
          ),
          const TrainSectionTitle('Program'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TrainChoice(
                label: 'Existing program',
                selected: !_ownMode,
                onTap: () => setState(() => _ownMode = false),
              ),
              TrainChoice(
                label: 'Create my own',
                selected: _ownMode,
                onTap: () => setState(() => _ownMode = true),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!_ownMode)
            DropdownButtonFormField<int>(
              initialValue: _existingProgramId,
              isExpanded: true,
              decoration: progressField('Choose a program'),
              items: [
                for (final p in _approved)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      '${p.name} · ${goals[p.goal] ?? ''} · ${intensities[p.intensity] ?? ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _existingProgramId = v),
            )
          else if (_ownProgram == null)
            TrainButton(
              label: 'Create my program',
              icon: Icons.add,
              onPressed: _createOwn,
            )
          else
            TrainCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  const TrainIconTile(icon: Icons.check, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_ownProgram!.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: TrainStyle.navy)),
                  ),
                  TextButton(onPressed: _createOwn, child: const Text('Change')),
                ],
              ),
            ),
          const SizedBox(height: 20),
          _errorText(_error),
          TrainButton(
            label: _saving ? 'Starting...' : 'Start plan',
            icon: Icons.play_arrow_rounded,
            onPressed: _start,
          ),
        ],
      ),
    );
  }

  /// What the target field shows: the typed value, with the change, or a dash.
  String _targetPreview(double? current) {
    final t = parseNumber(_target.text);
    if (t == null) return '--';
    if (current != null) {
      final diff = t - current;
      final sign = diff > 0 ? '+' : '';
      return '${t.toStringAsFixed(1)} kg ($sign${diff.toStringAsFixed(1)})';
    }
    return '${t.toStringAsFixed(1)} kg';
  }

  Widget _weightLabel(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: TrainStyle.navy)),
        ],
      );
}

// ---------------------------------------------------------------------------
// One week of data (new week or edit an existing week)
// ---------------------------------------------------------------------------

class WeekEntryPage extends StatefulWidget {
  final int planId;
  final int weekNo;

  /// Set when editing an existing week.
  final WeekEntry? existing;

  /// The week before this one. Its values pre-fill the form.
  final WeekEntry? previous;

  const WeekEntryPage({
    super.key,
    required this.planId,
    required this.weekNo,
    this.existing,
    this.previous,
  });

  @override
  State<WeekEntryPage> createState() => _WeekEntryPageState();
}

class _WeekEntryPageState extends State<WeekEntryPage> {
  final _repo = ProgressRepository();
  late final TextEditingController _weight;
  final Map<String, TextEditingController> _parts = {};
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.existing ?? widget.previous;
    final w = source?.weightKg;
    _weight = TextEditingController(text: w == null ? '' : w.toStringAsFixed(1));
    for (final part in bodyParts) {
      final v = source?.measures[part];
      _parts[part] =
          TextEditingController(text: v == null ? '' : v.toStringAsFixed(1));
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    for (final c in _parts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final weight = parseNumber(_weight.text);
    if (weight == null || weight < 30 || weight > 300) {
      setState(() => _error = 'Weight must be between 30 and 300 kg.');
      return;
    }
    final measures = <String, double>{};
    for (final e in _parts.entries) {
      final text = e.value.text.trim();
      if (text.isEmpty) continue;
      final v = parseNumber(text);
      if (v == null || v < 5 || v > 200) {
        setState(() => _error = '${e.key} must be between 5 and 200 cm.');
        return;
      }
      measures[e.key] = v;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await _repo.saveEntry(
      planId: widget.planId,
      weekNo: widget.weekNo,
      weight: weight,
      measures: measures,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      backgroundColor: TrainStyle.pageBg,
      appBar: trainAppBar(editing
          ? 'Edit week ${widget.weekNo}'
          : 'Week ${widget.weekNo} data'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            widget.previous == null
                ? 'Enter your measures for this week.'
                : 'Pre-filled from your last week. Change what has changed.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: progressField('Weight', suffix: 'kg'),
          ),
          const SizedBox(height: 12),
          const TrainSectionTitle('Body parts'),
          for (final part in bodyParts) _partField(part, _parts[part]!),
          _errorText(_error),
          TrainButton(
            label: _saving ? 'Saving...' : 'Save week',
            icon: Icons.check,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}