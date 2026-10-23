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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to ${_formatStatus(newStatus)}')),
        );
        // Reload orders after successful update
        _reload();
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
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2F6BCB), Color(0xFF173B7A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Order Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Manage all customer orders', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Refresh orders',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2F6BCB), size: 22),
            ),
          ),
          const SizedBox(width: 8),
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
                constraints: BoxConstraints(maxWidth: width > 900 ? 900 : 720),
                child: Column(
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.softBlue.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border.withOpacity(0.3)),
                        ),
                        child: DropdownButtonFormField<String?>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Filter by status',
                            labelStyle: TextStyle(color: Color(0xFF667EEA), fontWeight: FontWeight.w600),
                            prefixIcon: Icon(Icons.filter_list_rounded, color: Color(0xFF667EEA), size: 24),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 18),
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          items: const [
                            DropdownMenuItem(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.list_alt, size: 18),
                                  SizedBox(width: 8),
                                  Text('All orders'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'placed',
                              child: Row(
                                children: [
                                  Icon(Icons.shopping_bag, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Placed'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'processing',
                              child: Row(
                                children: [
                                  Icon(Icons.hourglass_empty, size: 18, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Processing'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Completed'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'cancelled',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Cancelled'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _statusFilter = value;
                              _orders = _loadOrders();
                            });
                          },
                        ),
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
                          
                          // Group orders by status for better organization
                          final ordersByStatus = <String, List<StoreOrder>>{};
                          for (final order in orders) {
                            ordersByStatus.putIfAbsent(order.status, () => []).add(order);
                          }
                          
                          return ListView(
                            padding: const EdgeInsets.all(20),
                            key: ValueKey(_statusFilter ?? 'all_${orders.length}'),
                            children: [
                              if (_statusFilter == null) ...[
                                _buildStatusSection('Placed', ordersByStatus['placed'] ?? [], Colors.blue),
                                const SizedBox(height: 16),
                                _buildStatusSection('Processing', ordersByStatus['processing'] ?? [], Colors.orange),
                                const SizedBox(height: 16),
                                _buildStatusSection('Completed', ordersByStatus['completed'] ?? [], Colors.green),
                                const SizedBox(height: 16),
                                _buildStatusSection('Cancelled', ordersByStatus['cancelled'] ?? [], Colors.red),
                              ] else
                                ...orders.map((order) => Padding(
                                  key: ValueKey('order_${order.id}_${order.status}'),
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _OrderCard(order: order, onUpdateStatus: _updateStatus),
                                )),
                            ],
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

  Widget _buildStatusSection(String title, List<StoreOrder> orders, Color color) {
    if (orders.isEmpty) return const SizedBox.shrink();
    
    // Use blue-grey palette based on status
    Color sectionColor;
    switch (title.toLowerCase()) {
      case 'placed':
        sectionColor = Color(0xFF2F6BCB); // Primary blue
        break;
      case 'processing':
        sectionColor = Color(0xFF5A6577); // Grey
        break;
      case 'completed':
        sectionColor = Color(0xFF173B7A); // Deep blue
        break;
      case 'cancelled':
        sectionColor = Color(0xFF6B7280); // Light grey
        break;
      default:
        sectionColor = Color(0xFF2F6BCB);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [sectionColor, sectionColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: sectionColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getStatusIcon(title), size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Colors.white70,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${orders.length} ${orders.length == 1 ? "order" : "orders"}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${orders.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: sectionColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...orders.map((order) => Padding(
          key: ValueKey('order_${order.id}_${order.status}'),
          padding: const EdgeInsets.only(bottom: 16),
          child: _OrderCard(order: order, onUpdateStatus: _updateStatus),
        )),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Icons.shopping_bag;
      case 'processing':
        return Icons.hourglass_empty;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }
}

class _OrderCard extends StatelessWidget {
  final StoreOrder order;
  final Function(StoreOrder, String) onUpdateStatus;

  const _OrderCard({
    required this.order,
    required this.onUpdateStatus,
  });

  MaterialColor _getStatusColor() {
    switch (order.status) {
      case 'placed': return Colors.blue;
      case 'processing': return Colors.orange;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    // Create color variations for non-MaterialColor usage
    final lightStatusColor = Color.lerp(statusColor, Colors.white, 0.95)!;
    final darkStatusColor = Color.lerp(statusColor, Colors.black, 0.3)!;
    
    return Container(
      key: ValueKey('order_card_${order.id}_${order.status}'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          childrenPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor.shade400, statusColor.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Order #${order.id}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              _StatusBadge(status: order.status),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      order.buyerName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${order.items.length} items'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      order.createdAt,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          children: [
            Container(
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.03),
                border: Border(top: BorderSide(color: statusColor.withOpacity(0.2))),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 18, color: statusColor),
                            const SizedBox(width: 8),
                            const Text('Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${item.quantity}×',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: darkStatusColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.productTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${storePrice(item.lineTotalTnd)} TND',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              '${storePrice(order.totalTnd)} TND',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: darkStatusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Delivery section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.local_shipping_outlined, size: 18, color: statusColor),
                            const SizedBox(width: 8),
                            const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(icon: Icons.person, text: order.buyerName),
                        const SizedBox(height: 6),
                        _InfoRow(icon: Icons.phone, text: order.phone),
                        const SizedBox(height: 6),
                        _InfoRow(icon: Icons.location_on, text: order.deliveryAddress),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Actions section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor.withOpacity(0.08), statusColor.withOpacity(0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune, size: 18, color: statusColor),
                            const SizedBox(width: 8),
                            const Text('Update status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (order.status == 'placed')
                              FilledButton.icon(
                                onPressed: () => onUpdateStatus(order, 'processing'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.orange.shade600,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.hourglass_empty, size: 18),
                                label: const Text('Start processing'),
                              ),
                            if (order.status == 'processing')
                              FilledButton.icon(
                                onPressed: () => onUpdateStatus(order, 'completed'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.check_circle, size: 18),
                                label: const Text('Mark completed'),
                              ),
                            if (order.status != 'cancelled' && order.status != 'completed')
                              OutlinedButton.icon(
                                onPressed: () => onUpdateStatus(order, 'cancelled'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade700),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
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
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
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
