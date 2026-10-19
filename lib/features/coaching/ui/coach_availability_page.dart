import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../data/coach_booking_repository.dart';

class CoachAvailabilityPage extends ConsumerStatefulWidget {
  const CoachAvailabilityPage({super.key});

  @override
  ConsumerState<CoachAvailabilityPage> createState() =>
      _CoachAvailabilityPageState();
}

class _CoachAvailabilityPageState extends ConsumerState<CoachAvailabilityPage> {
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final _repository = CoachBookingRepository();
  int _weekday = DateTime.monday;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 12, minute: 0);
  int _duration = 60;
  String _mode = 'online';
  final _price = TextEditingController(text: '40');
  int? _editingAvailabilityId;
  List<Map<String, Object?>> _rules = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final coach = ref.read(sessionProvider);
    if (coach == null) return;
    try {
      final rules = await _repository.availability(coach.id);
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load availability: $error');
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = selected;
      } else {
        _end = selected;
      }
    });
  }

  Future<void> _save() async {
    final coach = ref.read(sessionProvider);
    final price = double.tryParse(_price.text.trim());
    if (coach == null || price == null || price < 0) {
      _message('Enter a valid price.');
      return;
    }
    setState(() => _saving = true);
    try {
      final editingId = _editingAvailabilityId;
      if (editingId == null) {
        await _repository.addWeeklyAvailability(
          coachId: coach.id,
          weekday: _weekday,
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
          slotMinutes: _duration,
          mode: _mode,
          priceTnd: price,
        );
      } else {
        await _repository.editWeeklyAvailability(
          coachId: coach.id,
          availabilityId: editingId,
          weekday: _weekday,
          startTime: _formatTime(_start),
          endTime: _formatTime(_end),
          slotMinutes: _duration,
          mode: _mode,
          priceTnd: price,
        );
      }
      if (!mounted) return;
      setState(() => _editingAvailabilityId = null);
      _message(
        editingId == null
            ? 'Weekly availability saved and appointments generated for 8 weeks.'
            : 'Availability updated. Existing booked appointments are unchanged.',
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      _message('Could not save availability: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _edit(Map<String, Object?> rule) {
    final start = (rule['start_time'] as String).split(':');
    final end = (rule['end_time'] as String).split(':');
    setState(() {
      _editingAvailabilityId = rule['id'] as int;
      _weekday = rule['weekday'] as int;
      _start = TimeOfDay(hour: int.parse(start[0]), minute: int.parse(start[1]));
      _end = TimeOfDay(hour: int.parse(end[0]), minute: int.parse(end[1]));
      _duration = rule['slot_minutes'] as int;
      _mode = rule['mode'] as String;
      _price.text = (rule['price_tnd'] as num).toString();
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingAvailabilityId = null;
      _weekday = DateTime.monday;
      _start = const TimeOfDay(hour: 9, minute: 0);
      _end = const TimeOfDay(hour: 12, minute: 0);
      _duration = 60;
      _mode = 'online';
      _price.text = '40';
    });
  }

  Future<void> _remove(int availabilityId) async {
    final coach = ref.read(sessionProvider);
    if (coach == null) return;
    try {
      await _repository.removeAvailability(coach.id, availabilityId);
      if (!mounted) return;
      if (_editingAvailabilityId == availabilityId) _cancelEditing();
      _message('Availability removed. Existing booked appointments are unchanged.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _message('Could not remove availability: $error');
    }
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly availability')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _editingAvailabilityId == null
                ? 'Set a weekly window'
                : 'Edit weekly window',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _weekday,
            decoration: const InputDecoration(labelText: 'Day'),
            items: [
              for (var i = 0; i < _weekdays.length; i++)
                DropdownMenuItem(value: i + 1, child: Text(_weekdays[i])),
            ],
            onChanged: (value) => setState(() => _weekday = value!),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text('From ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text('Until ${_end.format(context)}'),
                ),
              ),
            ],
          ),
          DropdownButtonFormField<int>(
            value: _duration,
            decoration: const InputDecoration(labelText: 'Appointment length'),
            items: const [
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 45, child: Text('45 minutes')),
              DropdownMenuItem(value: 60, child: Text('60 minutes')),
              DropdownMenuItem(value: 90, child: Text('90 minutes')),
            ],
            onChanged: (value) => setState(() => _duration = value!),
          ),
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(labelText: 'Session type'),
            items: const [
              DropdownMenuItem(value: 'online', child: Text('Online')),
              DropdownMenuItem(value: 'in_person', child: Text('In person')),
            ],
            onChanged: (value) => setState(() => _mode = value!),
          ),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (TND)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const CircularProgressIndicator()
                : Text(
                    _editingAvailabilityId == null
                        ? 'Save and generate appointments'
                        : 'Save changes',
                  ),
          ),
          if (_editingAvailabilityId != null)
            TextButton(
              onPressed: _saving ? null : _cancelEditing,
              child: const Text('Cancel editing'),
            ),
          const SizedBox(height: 24),
          Text('Current weekly windows',
              style: Theme.of(context).textTheme.titleLarge),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rules.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('You have not set availability yet.'),
            )
          else
            for (final rule in _rules)
              Card(
                child: ListTile(
                  title: Text(
                    '${_weekdays[(rule['weekday'] as int) - 1]} · '
                    '${rule['start_time']}–${rule['end_time']}',
                  ),
                  subtitle: Text(
                    '${rule['slot_minutes']} min · '
                    '${rule['mode'] == 'online' ? 'Online' : 'In person'} · '
                    '${rule['price_tnd']} TND',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Edit availability',
                        onPressed: () => _edit(rule),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Remove future free appointments',
                        onPressed: () => _remove(rule['id'] as int),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'New windows generate appointments for the next 8 weeks. '
              'Booked appointments are never deleted by removing a window.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
