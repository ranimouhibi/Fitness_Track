import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/progress_repository.dart';
import 'progress_forms.dart';
import 'progress_plan_page.dart';
import 'widgets/training_style.dart';

/// Progress section: profile data, body measures and followed plans.
/// Shown for user accounts only.
class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  final _repo = ProgressRepository();
  ProfileData? _profile;
  List<PlanSummary> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider);
    if (user == null || user.role != UserRole.user) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final profile = await _repo.profile(user.id);
    final plans = await _repo.plans(user.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _plans = plans;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: _profile!)),
    );
    if (saved == true) await _load();
  }

  Future<void> _startPlan(int userId) async {
    final started = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => StartProgressPage(userId: userId)),
    );
    if (started == true) await _load();
  }

  Future<void> _openPlan(PlanSummary plan) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProgressPlanPage(plan: plan)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    if (user == null || user.role != UserRole.user) {
      return const TrainEmpty('Progress is tracked for user accounts.');
    }
    if (_loading || _profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final profile = _profile!;
    final hasActive = _plans.any((p) => p.isActive);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _ProfileCard(profile: profile, onEdit: _editProfile),
          const TrainSectionTitle('Body measurements'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: [
              for (final part in bodyParts)
                _MeasureTile(name: part, value: profile.measures[part]),
            ],
          ),
          const TrainSectionTitle('My progress'),
          if (_plans.isEmpty)
            const TrainCard(
              margin: EdgeInsets.zero,
              child: Text(
                'You are not following a progress plan yet.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final plan in _plans)
              _PlanCard(plan: plan, onTap: () => _openPlan(plan)),
          const SizedBox(height: 16),
          if (hasActive)
            const TrainCard(
              margin: EdgeInsets.zero,
              child: Text(
                'You already follow a plan. Finish or stop it to start another one.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            TrainButton(
              label: 'Start following progress',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _startPlan(user.id),
            ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final ProfileData profile;
  final VoidCallback onEdit;

  const _ProfileCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final h = profile.heightCm;
    final w = profile.weightKg;
    final bmi = (h != null && w != null && h > 0)
        ? w / ((h / 100) * (h / 100))
        : null;
    final initials = profile.fullName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: TrainStyle.hero,
        borderRadius: BorderRadius.circular(24),
        boxShadow: TrainStyle.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: TrainStyle.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(
                      profile.age == null
                          ? 'Age not set'
                          : '${profile.age} years old',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit measurements',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _WhiteStat(
                label: 'Height',
                value: h == null ? '--' : '${h.toStringAsFixed(0)} cm',
              ),
              _WhiteStat(
                label: 'Weight',
                value: w == null ? '--' : '${w.toStringAsFixed(1)} kg',
              ),
              _WhiteStat(
                label: 'BMI',
                value: bmi == null ? '--' : bmi.toStringAsFixed(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteStat extends StatelessWidget {
  final String label;
  final String value;

  const _WhiteStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _MeasureTile extends StatelessWidget {
  final String name;
  final double? value;

  const _MeasureTile({required this.name, this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TrainStyle.line),
        boxShadow: TrainStyle.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value == null ? '--' : '${value!.toStringAsFixed(1)} cm',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TrainStyle.navy),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanSummary plan;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (plan.status) {
      'active' => ('Active', Colors.green),
      'stopped' => ('Stopped', Colors.red),
      _ => ('Finished', AppColors.textSecondary),
    };
    return TrainCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const TrainIconTile(icon: Icons.flag_outlined, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.objective,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: TrainStyle.navy)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TrainPill(label, color: color),
                    TrainPill('${plan.durationWeeks} wks',
                        icon: Icons.calendar_today, color: AppColors.primary),
                    if (plan.programName != null)
                      TrainPill(plan.programName!, icon: Icons.fitness_center),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}