import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/contact_request_model.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class SellerContactRequestsPage extends ConsumerStatefulWidget {
  const SellerContactRequestsPage({super.key});

  @override
  ConsumerState<SellerContactRequestsPage> createState() => _SellerContactRequestsPageState();
}

class _SellerContactRequestsPageState extends ConsumerState<SellerContactRequestsPage> {
  final _repository = StoreRepository();
  late Future<List<ContactRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    final user = ref.read(sessionProvider);
    if (user == null) {
      _requests = Future.value([]);
    } else {
      _requests = _repository.getContactRequestsForSeller(user.id);
    }
  }

  void _refresh() {
    setState(() => _loadRequests());
  }

  Future<void> _updateStatus(ContactRequest request, String newStatus) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;

    try {
      await _repository.updateContactRequestStatus(request.id, newStatus, user.id);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${_statusLabel(newStatus)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _copyPhone(String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phone number copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact requests')),
        body: const StoreMessage(
          icon: Icons.person_outline,
          title: 'Sign in required',
          message: 'Sign in to see your contact requests.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<ContactRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return StoreMessage(
              icon: Icons.error_outline,
              title: 'Error loading requests',
              message: 'Could not load contact requests.',
              onRetry: _refresh,
            );
          }

          final requests = snapshot.data ?? [];
          
          if (requests.isEmpty) {
            return const StoreMessage(
              icon: Icons.mail_outline,
              title: 'No contact requests',
              message: 'When buyers contact you about your products, they will appear here.',
            );
          }

          final pendingRequests = requests.where((r) => r.isPending).toList();
          final contactedRequests = requests.where((r) => r.isContacted).toList();
          final closedRequests = requests.where((r) => r.isClosed).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (pendingRequests.isNotEmpty) ...[
                _buildSectionHeader('Pending', pendingRequests.length, Colors.orange),
                const SizedBox(height: 8),
                ...pendingRequests.map((request) => _buildRequestCard(request)),
                const SizedBox(height: 20),
              ],
              if (contactedRequests.isNotEmpty) ...[
                _buildSectionHeader('Contacted', contactedRequests.length, Colors.blue),
                const SizedBox(height: 8),
                ...contactedRequests.map((request) => _buildRequestCard(request)),
                const SizedBox(height: 20),
              ],
              if (closedRequests.isNotEmpty) ...[
                _buildSectionHeader('Closed', closedRequests.length, AppColors.textSecondary),
                const SizedBox(height: 8),
                ...closedRequests.map((request) => _buildRequestCard(request)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(ContactRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: request.isPending 
              ? Colors.orange.shade200 
              : AppColors.border,
          width: request.isPending ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _statusColor(request.status),
                  child: Icon(
                    _statusIcon(request.status),
                    color: AppColors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.buyerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatDate(request.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_statusLabel(request.status)),
                  backgroundColor: _statusColor(request.status).withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: _statusColor(request.status),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Product info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sell_outlined, size: 20, color: AppColors.deepBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.productTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.deepBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone number
            Row(
              children: [
                const Icon(Icons.phone, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    request.buyerPhone,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy phone number',
                  onPressed: () => _copyPhone(request.buyerPhone),
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
            
            // Message
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Message:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.message,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
            
            // Actions
            if (!request.isClosed) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (request.isPending) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateStatus(request, 'closed'),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => _updateStatus(request, 'contacted'),
                        icon: const Icon(Icons.phone_in_talk, size: 18),
                        label: const Text('Mark as contacted'),
                      ),
                    ),
                  ],
                  if (request.isContacted) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _updateStatus(request, 'closed'),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Close request'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Nouveau';
      case 'contacted':
        return 'Contacté';
      case 'closed':
        return 'Fermé';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'contacted':
        return Colors.blue;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.notification_important;
      case 'contacted':
        return Icons.phone_in_talk;
      case 'closed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return 'Il y a ${diff.inMinutes}m';
        }
        return 'Il y a ${diff.inHours}h';
      } else if (diff.inDays < 7) {
        return 'Il y a ${diff.inDays}j';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}
