import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/nutrition_repository.dart';

class AddFoodPage extends ConsumerStatefulWidget {
  final bool isAdmin;
  final Food? existing;

  const AddFoodPage({super.key, this.isAdmin = false, this.existing});

  @override
  ConsumerState<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends ConsumerState<AddFoodPage> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _repo = NutritionRepository();

  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existing;
    if (f != null) {
      _name.text = f.name;
      _kcal.text = f.kcalPer100g.toStringAsFixed(1);
      _protein.text = f.proteinG.toStringAsFixed(1);
      _carbs.text = f.carbsG.toStringAsFixed(1);
      _fat.text = f.fatG.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  double? _parsePositive(String v) {
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return null;
    return n;
  }

  Future<void> _submit() async {
    // Validate
    final nameErr = Validators.requiredText(_name.text, 'the food name');
    if (nameErr != null) {
      setState(() => _error = nameErr);
      return;
    }
    final kcal = _parsePositive(_kcal.text);
    if (kcal == null) {
      setState(() => _error = 'Enter a valid calorie value.');
      return;
    }
    final protein = _parsePositive(_protein.text);
    final carbs = _parsePositive(_carbs.text);
    final fat = _parsePositive(_fat.text);
    if (protein == null || carbs == null || fat == null) {
      setState(() => _error = 'Protein, carbs and fat must be 0 or more.');
      return;
    }

    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = foodPayload(
      name: _name.text,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

    final existing = widget.existing;
    if (existing != null && widget.isAdmin) {
      await _repo.updateFood(existing.id, payload);
    } else {
      await _repo.addFood(
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
    final title =
        editing ? 'Edit food' : (widget.isAdmin ? 'Add food' : 'Add a food');
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
              child: Text(
                  'Reviewed by an admin before it appears in the app.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: _dec('Food name'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Macros per 100 g'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _kcal,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _dec('Calories (kcal)'))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: _protein,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _dec('Protein (g)'))),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                      controller: _carbs,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: _dec('Carbs (g)'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fat,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Fat (g)'),
          ),
          const SizedBox(height: 20),
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

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary));
  }
}
