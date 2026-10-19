import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/change_request_repository.dart';
import '../data/program_repository.dart';
import 'add_program_page.dart';
import 'pending_requests_page.dart';

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

  /// Admin can manage any approved program. Users and coaches only their own.
  bool _canManage(Program p) {
    final user = ref.read(sessionProvider);
    if (user == null || p.status != 'approved') return false;
    return widget.isAdmin || p.createdBy == user.id;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        _Header(
          title: _title,
          canGoBack: !_atHome,
          onBack: _back,
          onAdd: _add,
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
      padding: const EdgeInsets.all(16),
      children: [
        _GoalCard(
          title: 'Gain weight',
          subtitle: 'Build muscle and strength',
          image: 'assets/programs/gain.jpg',
          onTap: () => _openGoal('gain'),
        ),
        const SizedBox(height: 12),
        _GoalCard(
          title: 'Lose weight',
          subtitle: 'Burn fat and get lean',
          image: 'assets/programs/lose.jpg',
          onTap: () => _openGoal('lose'),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: Icon(
              widget.isAdmin ? Icons.pending_actions : Icons.inbox_outlined,
              color: AppColors.deepBlue,
            ),
            title: Text(
              widget.isAdmin ? 'Pending requests' : 'My requests',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(widget.isAdmin
                ? 'New programs and edit or delete requests'
                : 'Programs you added and their status'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.isAdmin ? _openPending : _openRequests,
          ),
        ),
      ],
    );
  }

  Widget _intensityBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Intensity',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          for (final e in intensities.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: _intensity == e.key,
              onSelected: (_) {
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
      return Center(
        child: Text(
          _showRequests
              ? 'You have not added any programs yet.'
              : 'No programs at this level yet.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
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

class _Header extends StatelessWidget {
  final String title;
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _Header({
    required this.title,
    required this.canGoBack,
    required this.onBack,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 56, 8),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back))
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add program'),
          ),
        ],
      ),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(image, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: const TextStyle(
                                  color: AppColors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.white),
                  ],
                ),
              ),
            ],
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
          _StatusChip(status: program.status),
          IconButton(
            tooltip: 'Cancel request',
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onCancel,
          ),
        ],
      );
    } else if (showStatus) {
      trailing = _StatusChip(status: program.status);
    } else {
      trailing = const Icon(Icons.chevron_right);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.fitness_center, color: AppColors.deepBlue),
        ),
        title: Text(program.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${program.weeks} weeks · ${program.trainingDays} training days/week · '
          '${program.minutes} min',
        ),
        trailing: trailing,
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
      padding: const EdgeInsets.all(16),
      children: [
        Text(program.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoChip(text: goals[program.goal] ?? program.goal),
            _InfoChip(text: intensities[program.intensity] ?? program.intensity),
            _InfoChip(text: '${program.weeks} weeks'),
            _InfoChip(text: '${program.minutes} min per session'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.softBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.deepBlue),
              const SizedBox(width: 12),
              Text('${program.trainingDays} training days per week',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.deepBlue)),
            ],
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle('About'),
          Text(description, style: const TextStyle(height: 1.4)),
        ],
        const SizedBox(height: 20),
        const _SectionTitle('Weekly plan'),
        for (final day in program.days)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (_) => _DaySheet(day: day),
              ),
              leading: CircleAvatar(
                radius: 18,
                backgroundColor:
                    day.isRest ? AppColors.border : AppColors.primary,
                child: Icon(
                  day.isRest ? Icons.bedtime_outlined : Icons.fitness_center,
                  size: 18,
                  color:
                      day.isRest ? AppColors.textSecondary : AppColors.white,
                ),
              ),
              title: Text(day.weekday,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(day.isRest ? 'Rest' : day.muscle ?? ''),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
        if (canManage) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Delete',
                      style: TextStyle(color: Colors.red)),
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
            Text(day.weekday,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(day.isRest ? 'Rest' : day.muscle ?? '',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (day.isRest)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Rest',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepBlue)),
                ),
              ),
            if (!day.isRest)
              for (final e in day.exercises)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.softBlue,
                    child: Icon(Icons.fitness_center,
                        size: 16, color: AppColors.deepBlue),
                  ),
                  title: Text(e.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text('${e.sets} × ${e.reps}',
                      style: const TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', Colors.green),
      'refused' => ('Refused', Colors.red),
      _ => ('Pending', Colors.orange),
    };
    return Chip(
      label: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.deepBlue)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(text));
  }
}