import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/admin_request_repository.dart';

class RequestsInboxPage extends ConsumerStatefulWidget {
  const RequestsInboxPage({super.key});

  @override
  ConsumerState<RequestsInboxPage> createState() => _RequestsInboxPageState();
}

class _RequestsInboxPageState extends ConsumerState<RequestsInboxPage> {
  final _repo = AdminRequestRepository();
  List<AdminSignupRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final requests = await _repo.pendingSignups();
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _loading = false;
    });
  }

  Future<void> _decide(AdminSignupRequest request, bool accept) async {
    final admin = ref.read(sessionProvider);
    if (admin == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${accept ? 'Accept' : 'Decline'} request?'),
        content: Text(
            'This will ${accept ? 'accept' : 'decline'} ${request.name}\'s coach signup request.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(accept ? 'Accept' : 'Decline')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.decide(request: request, accept: accept, adminId: admin.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              '${request.name} was ${accept ? 'accepted' : 'declined'}.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(children: const [
                    SizedBox(height: 220),
                    Center(
                        child: Text('No pending signup requests.',
                            style: TextStyle(
                                color: AppColors.textSecondary))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (_, index) {
                      final request = _requests[index];
                      return _RequestCard(
                        request: request,
                        onAccept: () => _decide(request, true),
                        onDecline: () => _decide(request, false),
                      );
                    },
                  ),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AdminSignupRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              backgroundColor: AppColors.softBlue,
              child: Text(request.name[0],
                  style: const TextStyle(
                      color: AppColors.deepBlue, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(request.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(request.email,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ])),
            const Chip(label: Text('Pending')),
          ]),
          const Divider(height: 24),
          _DetailLine(label: 'Phone', value: request.phone ?? 'Not provided'),
          _DetailLine(
              label: 'Experience',
              value: request.yearsExperience == null
                  ? 'Not provided'
                  : '${request.yearsExperience} years'),
          _DetailLine(
              label: 'Certificate',
              value: request.certificatePath == null
                  ? 'Not provided'
                  : 'Uploaded'),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: onDecline, child: const Text('Decline'))),
            const SizedBox(width: 10),
            Expanded(
                child: FilledButton(
                    onPressed: onAccept, child: const Text('Accept'))),
          ]),
        ]),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;
  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(
              width: 92,
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value)),
        ]),
      );
}
