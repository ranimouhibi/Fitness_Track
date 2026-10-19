import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/coach_booking_repository.dart';

class CoachesPage extends StatefulWidget {
  const CoachesPage({super.key});

  @override
  State<CoachesPage> createState() => _CoachesPageState();
}

class _CoachesPageState extends State<CoachesPage> {
  final _repository = CoachBookingRepository();
  late Future<List<Map<String, Object?>>> _coaches;

  @override
  void initState() {
    super.initState();
    _coaches = _repository.coaches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a coach')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/my-bookings'),
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('My bookings and chats'),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _coaches,
              builder: (context, snapshot) {
                if (snapshot.hasError) return _error(snapshot.error!);
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final coaches = snapshot.data!;
                if (coaches.isEmpty) {
                  return const Center(child: Text('No approved coaches yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: coaches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final coach = coaches[index];
                    final name =
                        '${coach['first_name']} ${coach['last_name']}';
                    final experience = coach['years_experience'] as int?;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.fitness_center),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(experience == null
                                ? 'Approved FitTrack coach'
                                : '$experience years of experience'),
                            const SizedBox(height: 12),
                            const Text('Online and in-person sessions'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => context.push(
                                  '/coaches/book?coachId=${coach['id']}',
                                ),
                                child: const Text('View availability and book'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(Object error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load coaches: $error'),
        ),
      );
}
