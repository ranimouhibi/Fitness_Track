import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/nutrition_repository.dart';
import 'add_food_page.dart';
import 'pending_foods_page.dart';

class FoodsTab extends ConsumerStatefulWidget {
  final bool isAdmin;
  const FoodsTab({super.key, this.isAdmin = false});

  @override
  ConsumerState<FoodsTab> createState() => _FoodsTabState();
}

class _FoodsTabState extends ConsumerState<FoodsTab> {
  final _repo = NutritionRepository();

  bool _showRequests = false;
  Food? _detail;
  List<Food> _items = [];
  bool _loading = false;
  String _search = '';

  bool get _atHome => !_showRequests && _detail == null;

  String get _title {
    if (_detail != null) return _detail!.name;
    if (_showRequests) return widget.isAdmin ? 'Pending foods' : 'My requests';
    return 'Foods';
  }

  bool _canManage(Food f) {
    final user = ref.read(sessionProvider);
    if (user == null || f.status != 'approved') return false;
    return widget.isAdmin || f.createdBy == user.id;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    setState(() => _loading = true);
    final items = _showRequests
        ? await _repo.myFoodRequests(user.id)
        : await _repo.foodsFor(userId: user.id, isAdmin: widget.isAdmin);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openRequests() async {
    setState(() {
      _showRequests = true;
      _detail = null;
    });
    await _load();
  }

  Future<void> _openPending() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PendingFoodsPage()),
    );
    if (!_showRequests) await _load();
  }

  void _back() {
    setState(() {
      if (_detail != null) {
        _detail = null;
      } else {
        _showRequests = false;
        _items = [];
      }
    });
  }

  Future<void> _add() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddFoodPage(isAdmin: widget.isAdmin)),
    );
    if (saved != true) return;
    if (widget.isAdmin) {
      await _load();
    } else {
      await _openRequests();
    }
  }

  Future<void> _edit(Food f) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              AddFoodPage(isAdmin: widget.isAdmin, existing: f)),
    );
    if (saved != true) return;
    _toast(widget.isAdmin ? 'Food updated' : 'Edit sent to admin');
    setState(() => _detail = null);
    await _load();
  }

  Future<void> _delete(Food f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${f.name}?'),
        content: Text(widget.isAdmin
            ? 'This removes the food permanently.'
            : 'The admin will review this delete request.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (widget.isAdmin) {
        await _repo.deleteFood(f.id);
        _toast('Food deleted');
      } else {
        _toast('Delete request sent to admin');
      }
    } catch (_) {
      _toast('Could not delete this food.');
      return;
    }
    setState(() => _detail = null);
    await _load();
  }

  Future<void> _cancelRequest(Food f) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel request for ${f.name}?'),
        content: const Text('The food will be removed from pending.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel request')),
        ],
      ),
    );
    if (ok != true) return;
    final removed = await _repo.cancelOwnPendingFood(f.id, user.id);
    _toast(removed ? 'Request cancelled' : 'Could not cancel');
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Food> get _filtered {
    if (_search.trim().isEmpty) return _items;
    final q = _search.trim().toLowerCase();
    return _items.where((f) => f.name.toLowerCase().contains(q)).toList();
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
      final f = _detail!;
      return _FoodDetail(
        food: f,
        canManage: _canManage(f),
        onEdit: () => _edit(f),
        onDelete: () => _delete(f),
      );
    }
    if (_atHome) return _home();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search foods…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _home() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu,
                color: AppColors.deepBlue),
            title: const Text('All foods',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Browse approved foods and add new ones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              setState(() => _showRequests = false);
              await _load();
            },
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: Icon(
              widget.isAdmin
                  ? Icons.pending_actions
                  : Icons.inbox_outlined,
              color: AppColors.deepBlue,
            ),
            title: Text(
              widget.isAdmin ? 'Pending requests' : 'My requests',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(widget.isAdmin
                ? 'Foods waiting for your review'
                : 'Foods you submitted and their status'),
            trailing: const Icon(Icons.chevron_right),
            onTap: widget.isAdmin ? _openPending : _openRequests,
          ),
        ),
      ],
    );
  }

  Widget _list() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _showRequests
              ? 'You have not submitted any foods yet.'
              : 'No foods found.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final f = items[i];
        return _FoodCard(
          food: f,
          showStatus: _showRequests,
          canManage: _canManage(f),
          onTap: () => setState(() => _detail = f),
          onEdit: () => _edit(f),
          onDelete: () => _delete(f),
          onCancel: () => _cancelRequest(f),
        );
      },
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

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
            IconButton(
                onPressed: onBack, icon: const Icon(Icons.arrow_back))
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
            label: const Text('Add food'),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _FoodCard extends StatelessWidget {
  final Food food;
  final bool showStatus;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _FoodCard({
    required this.food,
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
    } else if (showStatus && food.status == 'pending') {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(status: food.status),
          IconButton(
            tooltip: 'Cancel request',
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onCancel,
          ),
        ],
      );
    } else if (showStatus) {
      trailing = _StatusChip(status: food.status);
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
          child: const Icon(Icons.restaurant_menu,
              color: AppColors.deepBlue),
        ),
        title: Text(food.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${food.kcalPer100g.toStringAsFixed(0)} kcal · '
            'P ${food.proteinG.toStringAsFixed(1)}g · '
            'C ${food.carbsG.toStringAsFixed(1)}g · '
            'F ${food.fatG.toStringAsFixed(1)}g  /100g'),
        trailing: trailing,
      ),
    );
  }
}

// ─── Detail ───────────────────────────────────────────────────────────────────

class _FoodDetail extends StatelessWidget {
  final Food food;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodDetail({
    required this.food,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(food.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        const _SectionTitle('Nutrition per 100 g'),
        const SizedBox(height: 8),
        Row(
          children: [
            _MacroCard(
                label: 'Calories',
                value: food.kcalPer100g,
                unit: 'kcal',
                color: const Color(0xFFFFF3E0)),
            const SizedBox(width: 10),
            _MacroCard(
                label: 'Protein',
                value: food.proteinG,
                unit: 'g',
                color: const Color(0xFFE3F2FD)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _MacroCard(
                label: 'Carbs',
                value: food.carbsG,
                unit: 'g',
                color: const Color(0xFFF3E5F5)),
            const SizedBox(width: 10),
            _MacroCard(
                label: 'Fat',
                value: food.fatG,
                unit: 'g',
                color: const Color(0xFFE8F5E9)),
          ],
        ),
        if (canManage) ...[
          const SizedBox(height: 28),
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
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red),
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

class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.deepBlue));
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
