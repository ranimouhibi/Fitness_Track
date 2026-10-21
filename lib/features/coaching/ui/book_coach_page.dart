import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../data/coach_booking_repository.dart';

class BookCoachPage extends ConsumerStatefulWidget {
  final int coachId;

  const BookCoachPage({super.key, required this.coachId});

  @override
  ConsumerState<BookCoachPage> createState() => _BookCoachPageState();
}

class _BookCoachPageState extends ConsumerState<BookCoachPage> {
  final _repository = CoachBookingRepository();
  DateTime _day = DateTime.now();
  Map<String, Object?>? _coach;
  List<Map<String, Object?>> _slots = [];
  int? _selectedSlot;
  String _payment = 'cash';
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.freeSlots(widget.coachId, _day),
        _repository.coachDetails(widget.coachId),
      ]);
      if (!mounted) return;
      setState(() {
        _slots = results[0] as List<Map<String, Object?>>;
        _coach = results[1] as Map<String, Object?>?;
        _selectedSlot = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _chooseDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = today.add(const Duration(days: 56));
    final initialDay =
        _day.isBefore(today) || _day.isAfter(lastDay) ? today : _day;
    final day = await showDatePicker(
      context: context,
      initialDate: initialDay,
      firstDate: today,
      lastDate: lastDay,
    );
    if (day == null || !mounted) return;
    setState(() => _day = day);
    await _loadSlots();
  }

  Future<void> _book() async {
    final user = ref.read(sessionProvider);
    final slotId = _selectedSlot;
    if (user == null || slotId == null) {
      _showMessage('Sign in and choose an available appointment.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _repository.requestBooking(
        userId: user.id,
        coachId: widget.coachId,
        slotId: slotId,
        payment: _payment,
      );
      if (!mounted) return;
      _showMessage('Booking request sent. The coach needs to accept it.');
      await _loadSlots();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not send booking request: $error');
      await _loadSlots();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book a coach')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_coach != null) ...[
            Text(
              '${_coach!['first_name']} ${_coach!['last_name']}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (_coach!['years_experience'] != null)
              Text('${_coach!['years_experience']} years of experience'),
            const SizedBox(height: 16),
          ] else if (!_loading)
            const Text('This coach is not available for booking.'),
          Text('Choose a day', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _chooseDay,
            icon: const Icon(Icons.calendar_month),
            label: Text(DateFormat.yMMMMd().format(_day)),
          ),
          const SizedBox(height: 16),
          Text('Available appointments',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text('Could not load appointments: $_error')
          else if (_slots.isEmpty)
            const Text('No free appointments for this day. Try another date.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _slots)
                  ChoiceChip(
                    selected: _selectedSlot == slot['id'],
                    label: Text(
                      '${DateFormat.jm().format(DateTime.parse(slot['starts_at'] as String))} · '
                      '${slot['mode'] == 'online' ? 'Online' : 'In person'} · '
                      '${slot['price_tnd']} TND',
                    ),
                    onSelected: (_) =>
                        setState(() => _selectedSlot = slot['id'] as int),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          Text('Payment method',
              style: Theme.of(context).textTheme.titleMedium),
          RadioListTile<String>(
            value: 'cash',
            groupValue: _payment,
            title: const Text('Cash'),
            onChanged: (value) => setState(() => _payment = value!),
          ),
          RadioListTile<String>(
            value: 'online',
            groupValue: _payment,
            title: const Text('Online'),
            onChanged: (value) => setState(() => _payment = value!),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitting || _selectedSlot == null ? null : _book,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Request booking'),
          ),
        ],
      ),
    );
  }
}
