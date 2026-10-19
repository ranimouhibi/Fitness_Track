import 'package:flutter/material.dart';
import 'foods_tab.dart';
import 'meal_log_tab.dart';
import 'supplements_tab.dart';

enum _Section { foods, mealLog, supplements }

class NutritionPage extends StatefulWidget {
  final bool isAdmin;
  const NutritionPage({super.key, this.isAdmin = false});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  _Section _section = _Section.foods;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 56, 8),
            child: SegmentedButton<_Section>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Section.foods, label: Text('Foods')),
                ButtonSegment(value: _Section.mealLog, label: Text('Meal Log')),
                ButtonSegment(
                    value: _Section.supplements, label: Text('Supplements')),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (_section) {
      case _Section.foods:
        return FoodsTab(isAdmin: widget.isAdmin);
      case _Section.mealLog:
        return const MealLogTab();
      case _Section.supplements:
        return const SupplementsTab();
    }
  }
}
