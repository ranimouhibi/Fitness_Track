import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../../progress/data/progress_repository.dart';
import '../data/coach_booking_repository.dart';

class BookingsPage extends ConsumerStatefulWidget {
  final bool isCoach;

  const BookingsPage({super.key, this.isCoach = true});

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage>
    with SingleTickerProviderStateMixin {
  final _repository = CoachBookingRepository();
  final _progressRepository = ProgressRepository();
  late final TabController _tabs;
  List<Map<String, Object?>> _bookings = [];
  bool _loading = true;
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final account = ref.read(sessionProvider);
    if (account == null) return;
    setState(() => _loading = true);
    try {
      final rows = widget.isCoach
          ? await _repository.bookingsForCoach(account.id)
          : await _repository.bookingsForClient(account.id);
      if (!mounted) return;
      setState(() {
        _bookings = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not load bookings: $error');
    }
  }

  Future<void> _act(
    int bookingId,
    Future<void> Function(int coachId) action,
    String success,
  ) async {
    final coach = ref.read(sessionProvider);
    if (coach == null) return;
    setState(() => _busyIds.add(bookingId));
    try {
      await action(coach.id);
      if (!mounted) return;
      _message(success);
      await _load();
    } catch (error) {
      if (!mounted) return;
      _message('Could not update booking: $error');
      await _load();
    } finally {
      if (mounted) setState(() => _busyIds.remove(bookingId));
    }
  }

  Future<void> _reschedule(Map<String, Object?> booking) async {
    final coach = ref.read(sessionProvider);
    if (coach == null) return;
    final current = DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final initial = DateTime.tryParse(booking['starts_at'] as String);
    final requestedDay = initial == null
        ? today
        : DateTime(initial.year, initial.month, initial.day);
    final lastDay = today.add(const Duration(days: 56));
    final chosen = await showDatePicker(
      context: context,
      initialDate: requestedDay.isBefore(today) || requestedDay.isAfter(lastDay)
          ? today
          : requestedDay,
      firstDate: today,
      lastDate: lastDay,
    );
    if (chosen == null || !mounted) return;
    final slots = await _repository.freeSlots(coach.id, chosen);
    if (!mounted) return;
    if (slots.isEmpty) {
      _message('There are no free appointments on that day.');
      return;
    }
    final slot = await showModalBottomSheet<Map<String, Object?>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose a new appointment')),
            for (final item in slots)
              ListTile(
                title: Text(
                  DateFormat.yMMMMd().add_jm().format(
                    DateTime.parse(item['starts_at'] as String),
                  ),
                ),
                subtitle: Text(
                  '${item['mode'] == 'online' ? 'Online' : 'In person'} · '
                  '${item['price_tnd']} TND',
                ),
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (slot == null || !mounted) return;
    await _act(
      booking['id'] as int,
      (coachId) => _repository.reschedule(
        bookingId: booking['id'] as int,
        coachId: coachId,
        slotId: slot['id'] as int,
      ),
      'Booking updated.',
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _viewCheckins(Map<String, Object?> booking) async {
    try {
      final entries = await _progressRepository.latestCheckins(
        booking['user_id'] as int,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: entries.isEmpty
                ? const Center(child: Text('This client has no check-ins yet.'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'Client check-ins',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final entry in entries)
                        Card(
                          child: ListTile(
                            title: Text(
                              'Week ${entry['week_no']} · ${entry['check_date']}',
                            ),
                            subtitle: Text(
                              [
                                if (entry['weight_kg'] != null)
                                  'Weight: ${entry['weight_kg']} kg',
                                if (entry['workouts_done'] != null)
                                  'Workouts: ${entry['workouts_done']}/'
                                      '${entry['workouts_planned'] ?? '?'}',
                                if (entry['energy'] != null)
                                  'Energy: ${entry['energy']}/5',
                                if (entry['waist_cm'] != null)
                                  'Waist: ${entry['waist_cm']} cm',
                                if (entry['chest_cm'] != null)
                                  'Chest: ${entry['chest_cm']} cm',
                                if (entry['notes'] != null &&
                                    (entry['notes'] as String).isNotEmpty)
                                  entry['notes'] as String,
                              ].join(' · '),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) _message('Could not load client check-ins: $error');
    }
  }

  void _openChat(int bookingId) {
    context.push('/chat?bookingId=$bookingId');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCoach ? 'Client bookings' : 'My bookings'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.isCoach)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push('/coach/availability'),
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Manage my availability'),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _bookingList('pending'),
                      _bookingList('accepted'),
                      _bookingList('ended', includeOtherClosed: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _bookingList(String status, {bool includeOtherClosed = false}) {
    final rows = _bookings.where((booking) {
      final current = booking['status'];
      return includeOtherClosed
          ? current == 'ended' ||
              current == 'declined' ||
              current == 'cancelled'
          : current == status;
    }).toList();
    if (rows.isEmpty) {
      return Center(child: Text('No ${includeOtherClosed ? 'past' : status} bookings.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _bookingCard(rows[index]),
      ),
    );
  }

  Widget _bookingCard(Map<String, Object?> booking) {
    final id = booking['id'] as int;
    final status = booking['status'] as String;
    final date = DateTime.parse(booking['starts_at'] as String);
    final busy = _busyIds.contains(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isCoach
                  ? '${booking['client_first_name']} ${booking['client_last_name']}'
                  : '${booking['coach_first_name']} ${booking['coach_last_name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(DateFormat.yMMMMd().add_jm().format(date)),
            Text(
              '${booking['mode'] == 'online' ? 'Online' : 'In person'} · '
              '${booking['price_tnd']} TND · '
              '${booking['payment'] == 'cash' ? 'Cash' : 'Online payment'}',
            ),
            if (widget.isCoach)
              TextButton.icon(
                onPressed: () => _viewCheckins(booking),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('View client check-ins'),
              ),
            const SizedBox(height: 8),
            Chip(label: Text(status[0].toUpperCase() + status.substring(1))),
            if (busy)
              const LinearProgressIndicator()
            else if (status == 'pending' && widget.isCoach)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: () => _act(
                      id,
                      (coachId) => _repository.accept(id, coachId),
                      'Booking accepted.',
                    ),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    onPressed: () => _act(
                      id,
                      (coachId) => _repository.decline(id, coachId),
                      'Booking declined.',
                    ),
                    child: const Text('Decline'),
                  ),
                ],
              )
            else if (status == 'accepted' && !widget.isCoach)
              FilledButton.icon(
                onPressed: () => _openChat(id),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Open chat'),
              )
            else if (status == 'accepted')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _openChat(id),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Open chat'),
                  ),
                  OutlinedButton(
                    onPressed: () => _reschedule(booking),
                    child: const Text('Edit appointment'),
                  ),
                  TextButton(
                    onPressed: () => _act(
                      id,
                      (coachId) => _repository.cancel(id, coachId),
                      'Booking cancelled.',
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
