import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/nutrition_repository.dart';

class MealLogTab extends ConsumerStatefulWidget {
  const MealLogTab({super.key});

  @override
  ConsumerState<MealLogTab> createState() => _MealLogTabState();
}

class _MealLogTabState extends ConsumerState<MealLogTab> {
  final _repo = NutritionRepository();
  DateTime _date = DateTime.now();
  List<MealLogEntry> _entries = [];
  bool _loading = false;

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);
  String get _dateLabel => DateFormat('EEE, MMM d').format(_date);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() => _loading = true);
    final entries = await _repo.logsForDay(user.id, _dateKey);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  void _prevDay() {
    setState(() => _date = _date.subtract(const Duration(days: 1)));
    _load();
  }

  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_date.isBefore(tomorrow)) {
      setState(() => _date = _date.add(const Duration(days: 1)));
      _load();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _addEntry() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddLogSheet(repo: _repo, date: _dateKey),
    );
    if (added == true) await _load();
  }

  Future<void> _deleteEntry(MealLogEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove entry?'),
        content: Text('Remove ${e.foodName} from ${mealTypes[e.mealType]}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteLog(e.id);
    await _load();
  }

  DaySummary get _totals => _entries.fold(
        DaySummary.zero,
        (sum, e) => sum +
            DaySummary(
                kcal: e.kcal,
                protein: e.protein,
                carbs: e.carbs,
                fat: e.fat),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DateBar(
          label: _dateLabel,
          onPrev: _prevDay,
          onNext: _nextDay,
          onPick: _pickDate,
          isToday: _dateKey ==
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _body(),
        ),
        _AddButton(onTap: _addEntry),
      ],
    );
  }

  Widget _body() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_meals_outlined,
                size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            const Text('Nothing logged yet.',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            TextButton(
                onPressed: _addEntry,
                child: const Text('Add your first entry')),
          ],
        ),
      );
    }

    final summary = _totals;
    final grouped = <String, List<MealLogEntry>>{};
    for (final e in _entries) {
      grouped.putIfAbsent(e.mealType, () => []).add(e);
    }
    final order = ['breakfast', 'lunch', 'dinner', 'snack'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _MacroSummary(summary: summary),
        const SizedBox(height: 16),
        for (final type in order)
          if (grouped.containsKey(type)) ...[
            _MealSection(
              type: type,
              entries: grouped[type]!,
              onDelete: _deleteEntry,
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

// ─── Date bar ─────────────────────────────────────────────────────────────────

class _DateBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final bool isToday;

  const _DateBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 56, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          TextButton(
            onPressed: onPick,
            child: Text(
              isToday ? 'Today' : label,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBlue),
            ),
          ),
          IconButton(
              onPressed: isToday ? null : onNext,
              icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

// ─── Macro summary ────────────────────────────────────────────────────────────

class _MacroSummary extends StatelessWidget {
  final DaySummary summary;
  const _MacroSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: AppColors.deepBlue),
              const SizedBox(width: 8),
              Text(
                '${summary.kcal.toStringAsFixed(0)} kcal today',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MacroPill(
                  label: 'Protein',
                  value: summary.protein,
                  color: Colors.blue.shade200),
              const SizedBox(width: 8),
              _MacroPill(
                  label: 'Carbs',
                  value: summary.carbs,
                  color: Colors.purple.shade200),
              const SizedBox(width: 8),
              _MacroPill(
                  label: 'Fat',
                  value: summary.fat,
                  color: Colors.green.shade200),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            Text('${value.toStringAsFixed(1)}g',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

// ─── Meal section ─────────────────────────────────────────────────────────────

class _MealSection extends StatelessWidget {
  final String type;
  final List<MealLogEntry> entries;
  final void Function(MealLogEntry) onDelete;

  const _MealSection({
    required this.type,
    required this.entries,
    required this.onDelete,
  });

  double get _totalKcal =>
      entries.fold(0, (s, e) => s + e.kcal);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  mealTypes[type] ?? type,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.deepBlue),
                ),
                const Spacer(),
                Text(
                  '${_totalKcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final e in entries)
            ListTile(
              dense: true,
              title: Text(e.foodName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${e.grams.toStringAsFixed(0)} g · '
                  '${e.kcal.toStringAsFixed(0)} kcal · '
                  'P ${e.protein.toStringAsFixed(1)} · '
                  'C ${e.carbs.toStringAsFixed(1)} · '
                  'F ${e.fat.toStringAsFixed(1)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                onPressed: () => onDelete(e),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Add button ───────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.add),
            label: const Text('Log a meal'),
          ),
        ),
      ),
    );
  }
}

// ─── Add log bottom sheet ─────────────────────────────────────────────────────

class _AddLogSheet extends ConsumerStatefulWidget {
  final NutritionRepository repo;
  final String date;

  const _AddLogSheet({required this.repo, required this.date});

  @override
  ConsumerState<_AddLogSheet> createState() => _AddLogSheetState();
}

class _AddLogSheetState extends ConsumerState<_AddLogSheet> {
  List<Food> _foods = [];
  Food? _selectedFood;
  String _mealType = 'breakfast';
  final _grams = TextEditingController(text: '100');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    final foods = await widget.repo.allApprovedFoods();
    if (!mounted) return;
    setState(() {
      _foods = foods;
      _selectedFood = foods.isNotEmpty ? foods.first : null;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final user = ref.read(sessionProvider);
    final food = _selectedFood;
    if (user == null || food == null) return;

    final grams = double.tryParse(_grams.text.trim());
    if (grams == null || grams <= 0) {
      setState(() => _error = 'Enter a valid gram amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await widget.repo.addLog(
      userId: user.id,
      foodId: food.id,
      grams: grams,
      mealType: _mealType,
      date: widget.date,
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 4,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Log a meal',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _mealType,
                  decoration: _dec('Meal'),
                  items: [
                    for (final e in mealTypes.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) =>
                      setState(() => _mealType = v ?? _mealType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Food>(
                  initialValue: _selectedFood,
                  decoration: _dec('Food'),
                  items: [
                    for (final f in _foods)
                      DropdownMenuItem(value: f, child: Text(f.name)),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedFood = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _grams,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: _dec('Amount (g)'),
                ),
                if (_selectedFood != null) ...[
                  const SizedBox(height: 8),
                  _preview(),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white),
                          )
                        : const Text('Add to log'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Widget _preview() {
    final f = _selectedFood!;
    final grams =
        double.tryParse(_grams.text.trim()) ?? 100;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PreviewMacro(
              label: 'kcal',
              value: f.kcalFor(grams).toStringAsFixed(0)),
          _PreviewMacro(
              label: 'protein',
              value: '${f.proteinFor(grams).toStringAsFixed(1)}g'),
          _PreviewMacro(
              label: 'carbs',
              value: '${f.carbsFor(grams).toStringAsFixed(1)}g'),
          _PreviewMacro(
              label: 'fat',
              value: '${f.fatFor(grams).toStringAsFixed(1)}g'),
        ],
      ),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        isDense: true,
      );
}

class _PreviewMacro extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewMacro({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.deepBlue)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
