import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/media/media_store.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/change_request_repository.dart';
import '../data/workout_repository.dart';
import 'add_exercise_page.dart';
import 'pending_requests_page.dart';
import 'widgets/training_style.dart';

class ExercisesTab extends ConsumerStatefulWidget {
  /// Admin sees every approved exercise and the pending requests.
  final bool isAdmin;
  const ExercisesTab({super.key, this.isAdmin = false});

  @override
  ConsumerState<ExercisesTab> createState() => _ExercisesTabState();
}

class _ExercisesTabState extends ConsumerState<ExercisesTab> {
  final _repo = WorkoutRepository();
  final _changes = ChangeRequestRepository();
  String? _group;
  bool _showRequests = false;
  Exercise? _detail;
  List<Exercise> _items = [];
  bool _loading = false;

  bool get _atHome => _group == null && !_showRequests && _detail == null;

  String get _title {
    if (_detail != null) return _detail!.name;
    if (_group != null) return _group!;
    if (_showRequests) return 'My requests';
    return 'Exercises';
  }

  String? get _subtitle {
    if (_detail != null) {
      return '${_detail!.muscleGroup} · ${_detail!.level ?? 'All levels'}';
    }
    if (_group != null) return 'Choose an exercise';
    if (_showRequests) return 'Your submissions';
    return 'Pick a body part';
  }

  /// Admin can manage any approved exercise. Users and coaches only their own.
  bool _canManage(Exercise e) {
    final user = ref.read(sessionProvider);
    if (user == null || e.status != 'approved') return false;
    return widget.isAdmin || e.createdBy == user.id;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  Future<void> _openGroup(String group) async {
    setState(() {
      _group = group;
      _showRequests = false;
      _detail = null;
    });
    await _load();
  }

  Future<void> _openRequests() async {
    setState(() {
      _group = null;
      _showRequests = true;
      _detail = null;
    });
    await _load();
  }

  Future<void> _openPending() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingRequestsPage(category: 'exercise'),
      ),
    );
    if (_group != null) await _load();
  }

  void _back() {
    setState(() {
      if (_detail != null) {
        _detail = null;
      } else if (_group != null) {
        _group = null;
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
    if (_group == null && !_showRequests) return;
    setState(() => _loading = true);
    final items = _showRequests
        ? await _repo.myRequests(user.id)
        : await _repo.exercisesForGroup(
            muscleGroup: _group!,
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
        builder: (_) => AddExercisePage(
          isAdmin: widget.isAdmin,
          initialGroup: _group,
        ),
      ),
    );
    if (saved != true) return;
    if (widget.isAdmin) {
      if (_group != null) await _load();
    } else {
      // After submitting, show the new request in My requests.
      await _openRequests();
    }
  }

  Future<void> _edit(Exercise e) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddExercisePage(isAdmin: widget.isAdmin, existing: e),
      ),
    );
    if (saved != true) return;
    _toast(widget.isAdmin ? 'Exercise updated' : 'Edit sent to admin');
    setState(() => _detail = null);
    await _load();
  }

  Future<void> _delete(Exercise e) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${e.name}?'),
        content: Text(widget.isAdmin
            ? 'This removes the exercise from the app.'
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
        await _repo.deleteExercise(e.id);
        _toast('Exercise deleted');
      } else {
        await _changes.submit(
          type: 'delete',
          table: 'exercises',
          targetId: e.id,
          userId: user.id,
          payload: {'target_name': e.name},
        );
        _toast('Delete request sent to admin');
      }
    } catch (_) {
      _toast('Cannot delete: this exercise is used in a program.');
      return;
    }
    setState(() => _detail = null);
    await _load();
  }

  /// Lets the submitter withdraw a new exercise that is still pending.
  Future<void> _cancelRequest(Exercise e) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel request for ${e.name}?'),
        content: const Text(
            'The exercise will be removed. The admin will not review it.'),
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
    final removed = await _repo.cancelOwnPending(e.id, user.id);
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
          actionLabel: 'Add exercise',
          onAction: _add,
        ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _body() {
    if (_detail != null) {
      final e = _detail!;
      return _ExerciseDetail(
        exercise: e,
        canManage: _canManage(e),
        onEdit: () => _edit(e),
        onDelete: () => _delete(e),
      );
    }
    if (_group == null && !_showRequests) return _categories();
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return TrainEmpty(_showRequests
          ? 'You have not submitted any exercises yet.'
          : 'No exercises in $_group yet.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final e = _items[i];
        return _ExerciseCard(
          exercise: e,
          showStatus: _showRequests,
          canManage: _canManage(e),
          onTap: () => setState(() => _detail = e),
          onEdit: () => _edit(e),
          onDelete: () => _delete(e),
          onCancel: () => _cancelRequest(e),
        );
      },
    );
  }

  Widget _categories() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.8,
          children: [
            for (final g in muscleGroups)
              _GroupTile(
                name: g,
                image: 'assets/muscles/${g.toLowerCase()}.png',
                onTap: () => _openGroup(g),
              ),
          ],
        ),
        const SizedBox(height: 10),
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
                          ? 'New exercises and edit or delete requests'
                          : 'Exercises you submitted and their status',
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
}

class _GroupTile extends StatelessWidget {
  final String name;
  final String image;
  final VoidCallback onTap;

  const _GroupTile({
    required this.name,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: TrainStyle.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration:
                      const BoxDecoration(gradient: TrainStyle.surface),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 46),
                  child: Image.asset(image, fit: BoxFit.contain),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          TrainStyle.navy.withValues(alpha: 0.92),
                          TrainStyle.navy.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            size: 12, color: Colors.white70),
                      ],
                    ),
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

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool showStatus;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _ExerciseCard({
    required this.exercise,
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
    } else if (showStatus && exercise.status == 'pending') {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TrainStatus(exercise.status),
          IconButton(
            tooltip: 'Cancel request',
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onCancel,
          ),
        ],
      );
    } else if (showStatus) {
      trailing = TrainStatus(exercise.status);
    } else {
      trailing = const Icon(Icons.chevron_right, color: AppColors.textSecondary);
    }

    return TrainCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          TrainThumb(path: exercise.mediaPath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
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
                    TrainPill(exercise.muscleGroup, color: AppColors.primary),
                    if ((exercise.equipment ?? '').isNotEmpty)
                      TrainPill(exercise.equipment!,
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

class _ExerciseDetail extends StatelessWidget {
  final Exercise exercise;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ExerciseDetail({
    required this.exercise,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final description = exercise.description ?? '';
    final steps = exercise.steps;

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  mediaImage(exercise.mediaPath),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 70,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            TrainStyle.navy.withValues(alpha: 0.55),
                            TrainStyle.navy.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          exercise.name,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: TrainStyle.navy,
              letterSpacing: 0.2),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TrainPill(exercise.muscleGroup,
                icon: Icons.accessibility_new, color: AppColors.primary),
            if ((exercise.equipment ?? '').isNotEmpty)
              TrainPill(exercise.equipment!, icon: Icons.fitness_center),
            if ((exercise.level ?? '').isNotEmpty)
              TrainPill(exercise.level!, icon: Icons.bar_chart),
          ],
        ),
        if (description.isNotEmpty) ...[
          const TrainSectionTitle('Description'),
          TrainCard(
            margin: EdgeInsets.zero,
            child: Text(description,
                style: const TextStyle(height: 1.5, fontSize: 14)),
          ),
        ],
        const TrainSectionTitle('Instructions'),
        if (steps.isEmpty)
          const TrainCard(
            margin: EdgeInsets.zero,
            child: Text('No instructions yet.',
                style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          for (var i = 0; i < steps.length; i++)
            TrainCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TrainBadge(i + 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(steps[i],
                          style: const TextStyle(height: 1.45, fontSize: 14)),
                    ),
                  ),
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