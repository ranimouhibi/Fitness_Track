import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../data/progress_repository.dart';
import 'progress_forms.dart';
import 'widgets/training_style.dart';

String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(1);

String _dateText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// One followed plan: summary, target, current data, chart, weekly data.
class ProgressPlanPage extends StatefulWidget {
  final PlanSummary plan;
  const ProgressPlanPage({super.key, required this.plan});

  @override
  State<ProgressPlanPage> createState() => _ProgressPlanPageState();
}

class _ProgressPlanPageState extends State<ProgressPlanPage> {
  final _repo = ProgressRepository();
  List<WeekEntry> _entries = [];
  int _nextWeek = 1;
  String _metric = 'Weight';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _repo.entries(widget.plan.id);
    final next = await _repo.nextWeekNo(widget.plan.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _nextWeek = next;
      _loading = false;
    });
  }

  bool get _canAddWeek =>
      widget.plan.isActive &&
      _nextWeek <= widget.plan.durationWeeks &&
      widget.plan.daysLeft > 0;

  Future<void> _openWeek({
    required int weekNo,
    WeekEntry? existing,
    WeekEntry? previous,
  }) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => WeekEntryPage(
          planId: widget.plan.id,
          weekNo: weekNo,
          existing: existing,
          previous: previous,
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop this plan?'),
        content:
            const Text('Your data stays saved, but you can no longer add weeks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.setPlanStatus(widget.plan.id, 'stopped');
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final start = _entries.isEmpty ? null : _entries.first;
    final latest = _entries.isEmpty ? null : _entries.last;
    final startW = start?.weightKg;
    final nowW = latest?.weightKg;
    final change = (startW != null && nowW != null) ? nowW - startW : null;

    return Scaffold(
      backgroundColor: TrainStyle.pageBg,
      appBar: trainAppBar(plan.objective),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _summaryCard(),
                if (plan.targetWeight != null) ...[
                  const SizedBox(height: 14),
                  _targetCard(nowW ?? startW),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  TrainStat(
                      icon: Icons.monitor_weight_outlined,
                      value: _fmt(startW),
                      label: 'Start kg'),
                  const SizedBox(width: 10),
                  TrainStat(
                      icon: Icons.scale_outlined,
                      value: _fmt(nowW),
                      label: 'Now kg'),
                  const SizedBox(width: 10),
                  TrainStat(
                      icon: (change != null && change > 0)
                          ? Icons.trending_up
                          : Icons.trending_down,
                      value: change == null
                          ? '--'
                          : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                      label: 'Change kg'),
                ]),
                const TrainSectionTitle('Weekly progress'),
                _metricChips(),
                const SizedBox(height: 10),
                TrainCard(
                  margin: EdgeInsets.zero,
                  child: SizedBox(height: 200, child: _chart()),
                ),
                const TrainSectionTitle('Current measures'),
                _currentMeasures(latest),
                const TrainSectionTitle('Weekly data'),
                if (_canAddWeek)
                  TrainButton(
                    label: 'Add week $_nextWeek',
                    icon: Icons.add,
                    onPressed: () => _openWeek(
                      weekNo: _nextWeek,
                      previous: _entries.isEmpty ? null : _entries.last,
                    ),
                  ),
                if (_canAddWeek) const SizedBox(height: 12),
                if (_entries.isEmpty)
                  const TrainEmpty('No data yet.')
                else
                  for (var i = _entries.length - 1; i >= 0; i--) _weekCard(i),
                if (plan.isActive) ...[
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _stop,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Colors.red),
                    label: const Text('Stop this plan',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
    );
  }

  /// Target, current weight and how far there is still to go.
  Widget _targetCard(double? current) {
    final target = widget.plan.targetWeight!;
    final toGo = current == null ? null : current - target;
    final losing = widget.plan.objective == 'Lose weight';
    final reached = toGo != null && (losing ? toGo <= 0 : toGo >= 0);

    final String toGoText;
    if (toGo == null) {
      toGoText = '--';
    } else if (reached) {
      toGoText = 'Reached';
    } else {
      toGoText = '${toGo.abs().toStringAsFixed(1)} kg to go';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TrainStyle.line),
        boxShadow: TrainStyle.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _valueColumn('Target', '${target.toStringAsFixed(1)} kg'),
          ),
          Expanded(
            child: _valueColumn('Current', '${_fmt(current)} kg'),
          ),
          Expanded(
            child: _valueColumn('Remaining', toGoText,
                highlight: reached ? Colors.green : AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _valueColumn(String label, String value, {Color? highlight}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: highlight ?? TrainStyle.navy)),
        ],
      );

  Widget _summaryCard() {
    final p = widget.plan;
    final String remaining;
    if (!p.isActive) {
      remaining = p.status == 'stopped' ? 'Stopped' : 'Finished';
    } else if (p.daysLeft == 0) {
      remaining = 'Duration ended';
    } else {
      remaining = '${p.daysLeft ~/ 7} wk ${p.daysLeft % 7} d left';
    }

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
          Text(p.objective,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(p.programName ?? 'No program',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          Row(children: [
            _info('Duration', '${p.durationWeeks} weeks'),
            _info('Ends', _dateText(p.endDay)),
            _info('Remaining', remaining),
          ]),
        ],
      ),
    );
  }

  Widget _info(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13)),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      );

  Widget _metricChips() {
    final options = ['Weight', ...bodyParts];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TrainChoice(
                label: o,
                selected: _metric == o,
                onTap: () => setState(() => _metric = o),
              ),
            ),
        ],
      ),
    );
  }

  /// Line chart of the selected metric. For weight, the target is drawn as a
  /// dashed green line so the gap to it is visible.
  Widget _chart() {
    final spots = <FlSpot>[];
    for (final e in _entries) {
      final v = _metric == 'Weight' ? e.weightKg : e.measures[_metric];
      if (v != null) spots.add(FlSpot(e.weekNo.toDouble(), v));
    }
    if (spots.isEmpty) {
      return Center(
        child: Text('No $_metric data yet. Add a week to see it here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
      );
    }

    final target = _metric == 'Weight' ? widget.plan.targetWeight : null;
    final values = [...spots.map((s) => s.y), if (target != null) target];
    final minY = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 2;
    final off = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: off,
            rightTitles: off,
            topTitles: off,
            bottomTitles: off,
          ),
          extraLinesData: target == null
              ? null
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: target,
                    color: Colors.green,
                    strokeWidth: 2,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      labelResolver: (_) =>
                          'Target ${target.toStringAsFixed(1)} kg',
                    ),
                  ),
                ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currentMeasures(WeekEntry? latest) {
    final m = latest?.measures ?? const <String, double>{};
    if (m.isEmpty) {
      return const TrainCard(
        margin: EdgeInsets.zero,
        child: Text('No measures recorded yet.',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return TrainCard(
      margin: EdgeInsets.zero,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final part in bodyParts)
            if (m[part] != null)
              TrainPill('$part ${m[part]!.toStringAsFixed(1)} cm',
                  color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _weekCard(int index) {
    final e = _entries[index];
    final previous = index > 0 ? _entries[index - 1] : null;
    final label = e.weekNo == 0 ? 'Start' : 'Week ${e.weekNo}';
    return TrainCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: widget.plan.isActive
          ? () => _openWeek(weekNo: e.weekNo, existing: e, previous: previous)
          : null,
      child: Row(
        children: [
          TrainBadge(e.weekNo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label · ${e.date}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: TrainStyle.navy)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TrainPill('${_fmt(e.weightKg)} kg',
                        icon: Icons.scale_outlined, color: AppColors.primary),
                    TrainPill('${e.measures.length} measures',
                        icon: Icons.straighten),
                  ],
                ),
              ],
            ),
          ),
          if (widget.plan.isActive)
            const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}