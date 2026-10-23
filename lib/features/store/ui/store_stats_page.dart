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
              child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Store Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Overview & analytics', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
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
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Key metrics grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 1.4,
                          children: [
                            _StatCard(
                              icon: Icons.storefront_rounded,
                              label: 'Official products',
                              value: '${stats.totalOfficialProducts}',
                              color: Color(0xFF2F6BCB),
                            ),
                            _StatCard(
                              icon: Icons.people_rounded,
                              label: 'Community products',
                              value: '${stats.totalCommunityProducts}',
                              color: Color(0xFF5A6577),
                            ),
                            _StatCard(
                              icon: Icons.shopping_cart_rounded,
                              label: 'Total orders',
                              value: '${stats.totalOrders}',
                              color: Color(0xFF173B7A),
                            ),
                            _StatCard(
                              icon: Icons.paid_rounded,
                              label: 'Total revenue',
                              value: '${storePrice(stats.totalRevenue)} TND',
                              color: Color(0xFF6B7280),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Orders by status
                        _SectionHeader(
                          icon: Icons.list_alt_rounded,
                          title: 'Orders by status',
                          color: Color(0xFF2F6BCB),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              _StatusRow(
                                label: 'Placed',
                                count: stats.ordersPlaced,
                                color: Colors.blue,
                                icon: Icons.shopping_bag_rounded,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              _StatusRow(
                                label: 'Processing',
                                count: stats.ordersProcessing,
                                color: Colors.blueGrey,
                                icon: Icons.hourglass_bottom_rounded,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              _StatusRow(
                                label: 'Completed',
                                count: stats.ordersCompleted,
                                color: Colors.indigo,
                                icon: Icons.check_circle_rounded,
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(height: 1, thickness: 1),
                              ),
                              _StatusRow(
                                label: 'Cancelled',
                                count: stats.ordersCancelled,
                                color: Colors.grey,
                                icon: Icons.cancel_rounded,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Stock alerts
                        _SectionHeader(
                          icon: Icons.warning_amber_rounded,
                          title: 'Stock alerts',
                          color: Color(0xFF5A6577),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                icon: Icons.inventory_rounded,
                                label: 'Low stock',
                                value: '${stats.lowStockCount}',
                                subtitle: 'Stock ≤ 5',
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                icon: Icons.remove_circle_rounded,
                                label: 'Out of stock',
                                value: '${stats.outOfStockCount}',
                                subtitle: 'Stock = 0',
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Pending reviews
                        _SectionHeader(
                          icon: Icons.pending_actions_rounded,
                          title: 'Pending reviews',
                          color: Color(0xFF173B7A),
                        ),
                        const SizedBox(height: 16),
                        _StatCard(
                          icon: Icons.rate_review_rounded,
                          label: 'Community requests',
                          value: '${stats.pendingRequests}',
                          subtitle: 'Awaiting approval',
                          color: Color(0xFF2F6BCB),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final int count;
  final MaterialColor color;
  final IconData icon;

  const _StatusRow({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.shade400, color.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: Colors.white),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.shade50, color.shade100],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.shade200, width: 2),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: color.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
