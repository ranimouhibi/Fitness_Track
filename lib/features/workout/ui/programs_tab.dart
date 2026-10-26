import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/media_store.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/change_request_repository.dart';
import '../data/program_repository.dart';
import 'add_program_page.dart';
import 'pending_requests_page.dart';
import 'widgets/training_style.dart';

class ProgramsTab extends ConsumerStatefulWidget {
  /// Admin sees every approved program and the pending requests.
  final bool isAdmin;
  const ProgramsTab({super.key, this.isAdmin = false});

  @override
  ConsumerState<ProgramsTab> createState() => _ProgramsTabState();
}

class _ProgramsTabState extends ConsumerState<ProgramsTab> {
  final _repo = ProgramRepository();
  final _changes = ChangeRequestRepository();
  String? _goal;
  String _intensity = 'low';
  bool _showRequests = false;
  Program? _detail;
  List<Program> _items = [];
  bool _loading = false;

  bool get _atHome => _goal == null && !_showRequests && _detail == null;

  String get _title {
    if (_detail != null) return _detail!.name;
    if (_goal != null) return goals[_goal]!;
    if (_showRequests) return 'My requests';
    return 'Programs';
  }

  String? get _subtitle {
    if (_detail != null) {
      return '${goals[_detail!.goal] ?? ''} · ${intensities[_detail!.intensity] ?? ''}';
    }
    if (_goal != null) return 'Choose an intensity level';
    if (_showRequests) return 'Your submissions';
    return 'Pick your goal';
  }

  /// Admin can manage any approved program. Users and coaches only their own.
  bool _canManage(Program p) {
    final user = ref.read(sessionProvider);
    if (user == null || p.status != 'approved') return false;
    return widget.isAdmin || p.createdBy == user.id;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _openGoal(String goal) async {
    setState(() {
      _goal = goal;
      _showRequests = false;
      _detail = null;
      _intensity = 'low';
    });
    await _load();
  }

  Future<void> _openRequests() async {
    setState(() {
      _goal = null;
      _showRequests = true;
      _detail = null;
    });
    await _load();
  }

  Future<void> _openPending() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingRequestsPage(category: 'program'),
      ),
    );
    if (_goal != null) await _load();
  }

  void _back() {
    setState(() {
      if (_detail != null) {
        _detail = null;
      } else if (_goal != null) {
        _goal = null;
        _items = [];
      } else {
        _showRequests = false;
        _items = [];
      }
    });
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    if (_goal == null && !_showRequests) return;
    setState(() => _loading = true);
    final items = _showRequests
        ? await _repo.myRequests(user.id)
        : await _repo.programsFor(
            goal: _goal!,
            intensity: _intensity,
            userId: user.id,
            isAdmin: widget.isAdmin,
          );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProgramPage(
          isAdmin: widget.isAdmin,
          initialGoal: _goal,
        ),
      ),
    );
    if (saved != true) return;
    if (widget.isAdmin) {
      if (_goal != null) await _load();
    } else {
      // After submitting, show the new program in My requests.
      await _openRequests();
    }
  }

  Future<void> _edit(Program p) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddProgramPage(
          isAdmin: widget.isAdmin,
          initialGoal: _goal,
          existing: p,
        ),
      ),
    );
    if (saved != true) return;
    _toast(widget.isAdmin ? 'Program updated' : 'Edit sent to admin');
    setState(() => _detail = null);
    await _load();
  }

  Future<void> _delete(Program p) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: Text(widget.isAdmin
            ? 'This removes the program from the app.'
            : 'The admin will review this delete request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (widget.isAdmin) {
        await _repo.deleteProgram(p.id);
        _toast('Program deleted');
      } else {
        await _changes.submit(
          type: 'delete',
          table: 'programs',
          targetId: p.id,
          userId: user.id,
          payload: {'target_name': p.name},
        );
        _toast('Delete request sent to admin');
      }
    } catch (_) {
      _toast('Could not delete this program.');
      return;
    }
    setState(() => _detail = null);
    await _load();
  }

  /// Lets the submitter withdraw a new program that is still pending.
  Future<void> _cancelRequest(Program p) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel request for ${p.name}?'),
        content: const Text(
            'The program will be removed. The admin will not review it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await _repo.cancelOwnPending(p.id, user.id);
    _toast(removed
        ? 'Request cancelled'
        : 'This request can no longer be cancelled');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TrainHeader(
          title: _title,
          subtitle: _subtitle,
          onBack: _atHome ? null : _back,
          actionLabel: 'Add program',
          onAction: _add,
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_detail != null) {
      final p = _detail!;
      return _ProgramDetail(
        program: p,
        canManage: _canManage(p),
        onEdit: () => _edit(p),
        onDelete: () => _delete(p),
      );
    }
    if (_goal == null && !_showRequests) return _home();
    return Column(
      children: [
        if (_goal != null) _intensityBar(),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _GoalCard(
          title: 'Gain weight',
          subtitle: 'Build muscle and strength',
          image: 'assets/programs/gain.jpg',
          onTap: () => _openGoal('gain'),
        ),
        const SizedBox(height: 14),
        _GoalCard(
          title: 'Lose weight',
          subtitle: 'Burn fat and get lean',
          image: 'assets/programs/lose.jpg',
          onTap: () => _openGoal('lose'),
        ),
        const SizedBox(height: 18),
        TrainCard(
          onTap: widget.isAdmin ? _openPending : _openRequests,
          child: Row(
            children: [
              TrainIconTile(
                icon: widget.isAdmin
                    ? Icons.pending_actions
                    : Icons.inbox_outlined,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isAdmin ? 'Pending requests' : 'My requests',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: TrainStyle.navy,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isAdmin
                          ? 'New programs and edit or delete requests'
                          : 'Programs you added and their status',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _intensityBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Intensity',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700)),
          for (final e in intensities.entries)
            TrainChoice(
              label: e.value,
              selected: _intensity == e.key,
              onTap: () {
                setState(() => _intensity = e.key);
                _load();
              },
            ),
        ],
      ),
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return TrainEmpty(_showRequests
          ? 'You have not added any programs yet.'
          : 'No programs at this level yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final p = _items[i];
        return _ProgramCard(
          program: p,
          showStatus: _showRequests,
          canManage: _canManage(p),
          onTap: () => setState(() => _detail = p),
          onEdit: () => _edit(p),
          onDelete: () => _delete(p),
          onCancel: () => _cancelRequest(p),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String image;
  final VoidCallback onTap;

  const _GoalCard({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: TrainStyle.glowShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                mediaImage(image),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        TrainStyle.navy.withValues(alpha: 0.9),
                        TrainStyle.navy.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final Program program;
  final bool showStatus;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _ProgramCard({
    required this.program,
    required this.showStatus,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    if (canManage) {
      trailing = PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
        onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );
    } else if (showStatus && program.status == 'pending') {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrainStatus(program.status),
          IconButton(
            tooltip: 'Cancel request',
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onCancel,
          ),
        ],
      );
    } else if (showStatus) {
      trailing = TrainStatus(program.status);
    } else {
      trailing = const Icon(Icons.chevron_right, color: AppColors.textSecondary);
    }

    return TrainCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          TrainThumb(path: program.mediaPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  program.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: TrainStyle.navy),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TrainPill('${program.weeks} wks',
                        icon: Icons.calendar_today,
                        color: AppColors.primary),
                    TrainPill('${program.trainingDays} days/wk',
                        icon: Icons.repeat,
                        color: AppColors.textSecondary),
                    TrainPill('${program.minutes} min',
                        icon: Icons.timer_outlined,
                        color: AppColors.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ProgramDetail extends StatelessWidget {
  final Program program;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProgramDetail({
    required this.program,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = program.description ?? '';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: TrainStyle.glowShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: mediaImage(program.mediaPath),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          program.name,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: TrainStyle.navy),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TrainPill(goals[program.goal] ?? program.goal,
                icon: program.goal == 'gain'
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: AppColors.primary),
            TrainPill(intensities[program.intensity] ?? program.intensity,
                icon: Icons.bolt),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TrainStat(
                icon: Icons.calendar_view_week,
                value: '${program.weeks}',
                label: 'Weeks'),
            const SizedBox(width: 10),
            TrainStat(
                icon: Icons.timer_outlined,
                value: '${program.minutes}',
                label: 'Min / session'),
            const SizedBox(width: 10),
            TrainStat(
                icon: Icons.fitness_center,
                value: '${program.trainingDays}',
                label: 'Days / week'),
          ],
        ),
        if (description.isNotEmpty) ...[
          const TrainSectionTitle('About'),
          TrainCard(
            margin: EdgeInsets.zero,
            child: Text(description,
                style: const TextStyle(height: 1.5, fontSize: 14)),
          ),
        ],
        const TrainSectionTitle('Weekly plan'),
        for (final day in program.days)
          TrainCard(
            margin: const EdgeInsets.only(bottom: 8),
            onTap: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              backgroundColor: Colors.white,
              builder: (_) => _DaySheet(day: day),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: day.isRest ? null : TrainStyle.accent,
                    color: day.isRest ? TrainStyle.line : null,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    day.isRest ? Icons.bedtime_outlined : Icons.fitness_center,
                    color: day.isRest ? AppColors.textSecondary : Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.weekday,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: TrainStyle.navy)),
                      const SizedBox(height: 2),
                      Text(day.isRest ? 'Rest' : day.muscle ?? '',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        if (canManage) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TrainButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Shows the exercises for one day, or "Rest".
class _DaySheet extends StatelessWidget {
  final ProgramDay day;
  const _DaySheet({required this.day});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TrainIconTile(
                  icon: day.isRest
                      ? Icons.bedtime_outlined
                      : Icons.fitness_center,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.weekday,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: TrainStyle.navy)),
                      Text(day.isRest ? 'Recovery day' : day.muscle ?? '',
                          style: const TextStyle(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (day.isRest)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Text('Rest',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary)),
                ),
              )
            else
              for (final e in day.exercises)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TrainStyle.line),
                    boxShadow: TrainStyle.softShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: TrainStyle.navy)),
                      ),
                      TrainPill('${e.sets} × ${e.reps}',
                          color: AppColors.primary),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}