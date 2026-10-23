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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.deepBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.mail, color: Colors.white),
            SizedBox(width: 8),
            Text('Contact Requests'),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              title == 'Pending' ? Icons.schedule :
              title == 'Contacted' ? Icons.phone_in_talk :
              Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(ContactRequest request) {
    final statusColor = _statusColor(request.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: request.isPending ? statusColor : AppColors.primary,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: statusColor, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(
                      _statusIcon(request.status),
                      color: statusColor,
                      size: 22,
                    ),
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
                          fontWeight: FontWeight.bold,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor, width: 1),
                  ),
                  child: Text(
                    _statusLabel(request.status),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
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
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.productTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Phone number
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.softBlue.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 20, color: AppColors.primary),
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
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      tooltip: 'Copy phone number',
                      onPressed: () => _copyPhone(request.buyerPhone),
                      icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            
            // Message
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.softBlue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.message, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Message:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request.message,
                      style: const TextStyle(height: 1.5),
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
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => _updateStatus(request, 'contacted'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.phone_in_talk, size: 18),
                        label: const Text('Mark as contacted'),
                      ),
                    ),
                  ],
                  if (request.isContacted) ...[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _updateStatus(request, 'closed'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
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
