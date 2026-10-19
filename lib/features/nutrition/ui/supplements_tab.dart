import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/nutrition_repository.dart';

class SupplementsTab extends StatefulWidget {
  const SupplementsTab({super.key});

  @override
  State<SupplementsTab> createState() => _SupplementsTabState();
}

class _SupplementsTabState extends State<SupplementsTab> {
  final _repo = NutritionRepository();
  List<Supplement> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _repo.supplements();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Text('No supplements found.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) => _SupplementCard(supp: _items[i]),
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final Supplement supp;
  const _SupplementCard({required this.supp});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.science_outlined,
              color: AppColors.deepBlue),
        ),
        title: Text(supp.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: supp.timing != null
            ? Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(supp.timing!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((supp.description ?? '').isNotEmpty) ...[
                  Text(supp.description!,
                      style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 12),
                ],
                if (supp.alternatives.isNotEmpty) ...[
                  const Text('Natural alternatives',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBlue,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final alt in supp.alternatives)
                        Chip(
                          avatar: const Icon(Icons.restaurant_menu,
                              size: 14,
                              color: AppColors.deepBlue),
                          label: Text(alt,
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppColors.softBlue,
                          side: BorderSide.none,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
