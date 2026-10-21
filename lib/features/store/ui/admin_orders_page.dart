import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final _repository = StoreRepository();
  late Future<List<StoreOrder>> _orders;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _orders = _loadOrders();
  }

  Future<List<StoreOrder>> _loadOrders() async {
    final adminId = ref.read(sessionProvider)?.id;
    if (adminId == null) return [];
    return _repository.allOrders(statusFilter: _statusFilter);
  }

  void _reload() => setState(() => _orders = _loadOrders());

  Future<void> _updateStatus(StoreOrder order, String newStatus) async {
    final adminId = ref.read(sessionProvider)?.id;
    if (adminId == null) return;
    
    try {
      await _repository.updateOrderStatus(order.id, newStatus, adminId);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to ${_formatStatus(newStatus)}')),
        );
      }
    } on StoreException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(sessionProvider)?.role == UserRole.admin;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage orders'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !admin
          ? const StoreMessage(
              icon: Icons.lock_outline,
              title: 'Administrator access required',
              message: 'Sign in with an administrator account to manage orders.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width > 900 ? 820 : 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: DropdownButtonFormField<String?>(
                        value: _statusFilter,
                        decoration: const InputDecoration(labelText: 'Filter by status'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All orders')),
                          DropdownMenuItem(value: 'placed', child: Text('Placed')),
                          DropdownMenuItem(value: 'processing', child: Text('Processing')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                          DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value;
                            _orders = _loadOrders();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<StoreOrder>>(
                        future: _orders,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return StoreMessage(
                              icon: Icons.error_outline,
                              title: 'Orders unavailable',
                              message: 'Could not load orders.',
                              onRetry: _reload,
                            );
                          }
                          final orders = snapshot.data ?? [];
                          if (orders.isEmpty) {
                            return const StoreMessage(
                              icon: Icons.receipt_long_outlined,
                              title: 'No orders',
                              message: 'Customer orders will appear here.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return _OrderCard(
                                order: order,
                                onUpdateStatus: _updateStatus,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final StoreOrder order;
  final Function(StoreOrder, String) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Order #${order.id}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            _StatusBadge(status: order.status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${order.buyerName} · ${order.items.length} items'),
            Text(
              order.createdAt,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.quantity}× ${item.productTitle}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          '${storePrice(item.lineTotalTnd)} TND',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '${storePrice(order.totalTnd)} TND',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(order.buyerName, style: const TextStyle(fontSize: 14)),
                Text(order.phone, style: const TextStyle(fontSize: 14)),
                Text(order.deliveryAddress, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                const Text('Update status', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    if (order.status == 'placed')
                      FilledButton.icon(
                        onPressed: () => onUpdateStatus(order, 'processing'),
                        icon: const Icon(Icons.hourglass_empty, size: 18),
                        label: const Text('Start processing'),
                      ),
                    if (order.status == 'processing')
                      FilledButton.icon(
                        onPressed: () => onUpdateStatus(order, 'completed'),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Mark completed'),
                      ),
                    if (order.status != 'cancelled' && order.status != 'completed')
                      OutlinedButton.icon(
                        onPressed: () => onUpdateStatus(order, 'cancelled'),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Cancel'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        config['label'],
        style: TextStyle(
          color: config['textColor'],
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'placed':
        return {
          'label': 'Placed',
          'color': AppColors.softBlue,
          'textColor': AppColors.deepBlue,
        };
      case 'processing':
        return {
          'label': 'Processing',
          'color': Colors.orange.shade100,
          'textColor': Colors.orange.shade900,
        };
      case 'completed':
        return {
          'label': 'Completed',
          'color': Colors.green.shade100,
          'textColor': Colors.green.shade900,
        };
      case 'cancelled':
        return {
          'label': 'Cancelled',
          'color': Colors.red.shade100,
          'textColor': Colors.red.shade900,
        };
      default:
        return {
          'label': status,
          'color': AppColors.softBlue,
          'textColor': AppColors.deepBlue,
        };
    }
  }
}

String _formatStatus(String status) => switch (status) {
      'placed' => 'Placed',
      'processing' => 'Processing',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };
