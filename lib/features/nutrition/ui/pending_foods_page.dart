import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../data/nutrition_repository.dart';

class PendingFoodsPage extends ConsumerStatefulWidget {
  const PendingFoodsPage({super.key});

  @override
  ConsumerState<PendingFoodsPage> createState() => _PendingFoodsPageState();
}

class _PendingFoodsPageState extends ConsumerState<PendingFoodsPage> {
  final _repo = NutritionRepository();
  List<(Food, String)> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.pendingFoods();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _decide(Food food, bool accept) async {
    await _repo.setFoodStatus(food.id, accept ? 'approved' : 'refused');
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(accept ? '${food.name} approved' : '${food.name} refused')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending foods')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Text('No pending foods.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final (food, submitter) = _items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(food.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.person_outline,
                                        size: 14),
                                    label: Text(submitter,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                    side: BorderSide.none,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _MacroRow(food: food),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          _decide(food, false),
                                      child: const Text('Refuse'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () =>
                                          _decide(food, true),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final Food food;
  const _MacroRow({required this.food});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _chip('${food.kcalPer100g.toStringAsFixed(0)} kcal'),
        _chip('P ${food.proteinG.toStringAsFixed(1)}g'),
        _chip('C ${food.carbsG.toStringAsFixed(1)}g'),
        _chip('F ${food.fatG.toStringAsFixed(1)}g'),
      ],
    );
  }

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppColors.softBlue,
        side: BorderSide.none,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
