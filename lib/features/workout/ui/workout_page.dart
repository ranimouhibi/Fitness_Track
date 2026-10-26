import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'exercises_tab.dart';
import 'progress_tab.dart';
import 'programs_tab.dart';
import 'widgets/training_style.dart';

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
      backgroundColor: TrainStyle.pageBg,
      appBar: AppBar(
        title: const Text('Training',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: TrainStyle.hero),
        ),
      ),
      body: Column(
        children: [
          // Right padding keeps the sign-out button clear.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 56, 6),
            child: _SegmentBar(
              selected: _section,
              onChanged: (s) => setState(() => _section = s),
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
        return const ProgressTab();
    }
  }
}

class _SegmentBar extends StatelessWidget {
  final _Section selected;
  final ValueChanged<_Section> onChanged;

  const _SegmentBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      (_Section.exercises, 'Exercises'),
      (_Section.programs, 'Programs'),
      (_Section.progress, 'Progress'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TrainStyle.line),
        boxShadow: TrainStyle.softShadow,
      ),
      child: Row(
        children: [
          for (final (section, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(section),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: section == selected ? TrainStyle.accent : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow:
                        section == selected ? TrainStyle.glowShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: section == selected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}