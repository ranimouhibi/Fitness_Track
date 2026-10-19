import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'exercises_tab.dart';
import 'programs_tab.dart';

enum _Section { exercises, programs, progress }

class WorkoutPage extends StatefulWidget {
  /// Admin gets the same page, with Pending requests instead of My requests.
  final bool isAdmin;
  const WorkoutPage({super.key, this.isAdmin = false});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> {
  _Section _section = _Section.exercises;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: Column(
        children: [
          // Right padding keeps the sign-out button clear.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 56, 8),
            child: SegmentedButton<_Section>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Section.exercises, label: Text('Exercises')),
                ButtonSegment(value: _Section.programs, label: Text('Programs')),
                ButtonSegment(value: _Section.progress, label: Text('Progress')),
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
      case _Section.exercises:
        return ExercisesTab(isAdmin: widget.isAdmin);
      case _Section.programs:
        return ProgramsTab(isAdmin: widget.isAdmin);
      case _Section.progress:
        return const Center(
          child: Text('Progress coming soon',
              style: TextStyle(color: AppColors.textSecondary)),
        );
    }
  }
}