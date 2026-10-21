import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class StoreStatsPage extends ConsumerWidget {
  const StoreStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(sessionProvider)?.role == UserRole.admin;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Store statistics')),
      body: !admin
          ? const StoreMessage(
              icon: Icons.lock_outline,
              title: 'Administrator access required',
              message: 'Sign in with an administrator account to view statistics.',
            )
          : FutureBuilder<StoreStats>(
              future: StoreRepository().getStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const StoreMessage(
                    icon: Icons.error_outline,
                    title: 'Stats unavailable',
                    message: 'Could not load statistics.',
                  );
                }
                final stats = snapshot.data!;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          'Overview',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.shopping_bag_outlined,
                                label: 'Official products',
                                value: '${stats.totalOfficialProducts}',
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.people_outline,
                                label: 'Community products',
                                value: '${stats.totalCommunityProducts}',
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.receipt_long_outlined,
                                label: 'Total orders',
                                value: '${stats.totalOrders}',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.attach_money,
                                label: 'Total revenue',
                                value: '${storePrice(stats.totalRevenue)} TND',
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Orders by status',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _StatusRow(label: 'Placed', count: stats.ordersPlaced),
                        _StatusRow(label: 'Processing', count: stats.ordersProcessing),
                        _StatusRow(label: 'Completed', count: stats.ordersCompleted),
                        _StatusRow(label: 'Cancelled', count: stats.ordersCancelled),
                        const SizedBox(height: 24),
                        Text(
                          'Stock alerts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _StatCard(
                          icon: Icons.warning_amber_outlined,
                          label: 'Low stock products',
                          value: '${stats.lowStockCount}',
                          subtitle: 'Products with stock ≤ 5',
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _StatCard(
                          icon: Icons.inventory_2_outlined,
                          label: 'Out of stock',
                          value: '${stats.outOfStockCount}',
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Pending reviews',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _StatCard(
                          icon: Icons.pending_outlined,
                          label: 'Community requests',
                          value: '${stats.pendingRequests}',
                          color: AppColors.deepBlue,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;

  const _StatusRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
