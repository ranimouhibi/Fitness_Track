import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class OrdersPage extends ConsumerWidget {
  final String basePath;

  const OrdersPage({super.key, required this.basePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My orders')),
        body: const StoreMessage(
          icon: Icons.person_outline,
          title: 'Sign in required',
          message: 'Sign in to see your order history.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: FutureBuilder<List<StoreOrder>>(
        future: StoreRepository().ordersForUser(user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Orders unavailable',
              message: 'Could not load your order history.',
            );
          }
          final orders = snapshot.data ?? const <StoreOrder>[];
          if (orders.isEmpty) {
            return const StoreMessage(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              message: 'Orders you place from the official store will appear here.',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: ListTile(
                      title: Text('Order #${order.id}'),
                      subtitle: Text('${order.items.length} items · $order.createdAt'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${storePrice(order.totalTnd)} TND', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(_statusLabel(order.status), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                      onTap: () => context.push('$basePath/orders/${order.id}'),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class OrderDetailsPage extends ConsumerWidget {
  final int orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider);
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order details')),
        body: const StoreMessage(
          icon: Icons.person_outline,
          title: 'Sign in required',
          message: 'Sign in to view this order.',
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Order #$orderId')),
      body: FutureBuilder<StoreOrder?>(
        future: StoreRepository().orderForUser(orderId, user.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Order unavailable',
              message: 'This order could not be found for your account.',
            );
          }
          final order = snapshot.data!;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Order details', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Status: ${_statusLabel(order.status)}'),
                  Text('Placed: ${order.createdAt}'),
                  const SizedBox(height: 18),
                  for (final item in order.items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productTitle),
                      subtitle: Text('${item.quantity} × ${storePrice(item.unitPriceTnd)} TND'),
                      trailing: Text('${storePrice(item.lineTotalTnd)} TND'),
                    ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Total: ${storePrice(order.totalTnd)} TND',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text(order.buyerName),
                  Text(order.phone),
                  Text(order.deliveryAddress),
                  const SizedBox(height: 20),
                  const Text(
                    'Order recorded. No payment was processed in the app.',
                    style: TextStyle(color: AppColors.textSecondary),
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

String _statusLabel(String status) => switch (status) {
      'placed' => 'Order recorded',
      'processing' => 'Processing',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => status,
    };
