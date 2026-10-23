import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_cart.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class CartPage extends ConsumerStatefulWidget {
  final String basePath;

  const CartPage({super.key, required this.basePath});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final _repository = StoreRepository();
  late Future<List<StoreProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts(ref.read(storeCartProvider).keys.toList());
  }

  Future<List<StoreProduct>> _loadProducts(List<int> ids) async {
    final products = await Future.wait(ids.map(_repository.publicProductById));
    return products.whereType<StoreProduct>().toList();
  }

  void _reloadProducts() {
    _products = _loadProducts(ref.read(storeCartProvider).keys.toList());
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(storeCartProvider);
    final width = MediaQuery.sizeOf(context).width;
    final itemCount = cart.values.fold<int>(0, (sum, qty) => sum + qty);

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
        title: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Cart'),
            const SizedBox(width: 8),
            if (itemCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
      body: FutureBuilder<List<StoreProduct>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Cart unavailable',
              message: 'Could not load the products in your cart.',
            );
          }
          final products = snapshot.data ?? const <StoreProduct>[];
          if (cart.isEmpty || products.isEmpty) {
            return const StoreMessage(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add an official product from the app store to start an order.',
            );
          }
          final total = products.fold<double>(
            0,
            (sum, product) => sum + product.priceTnd * (cart[product.id] ?? 0),
          );
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width > 800 ? 720 : 640),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        final quantity = cart[product.id] ?? 0;
                        final lineTotal = product.priceTnd * quantity;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: StoreProductTile(
                            product: product,
                            statusLabel: 'Line total: ${storePrice(lineTotal)} TND',
                            action: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.softBlue,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary, width: 1),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Decrease quantity',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          ref.read(storeCartProvider.notifier).setQuantity(product, quantity - 1);
                                          setState(_reloadProducts);
                                        },
                                        icon: const Icon(Icons.remove_circle, color: AppColors.primary),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Increase quantity',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: quantity < product.stock
                                            ? () {
                                                ref.read(storeCartProvider.notifier).setQuantity(product, quantity + 1);
                                                setState(_reloadProducts);
                                              }
                                            : null,
                                        icon: Icon(
                                          Icons.add_circle,
                                          color: quantity < product.stock ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Remove item',
                                    onPressed: () {
                                      ref.read(storeCartProvider.notifier).remove(product.id);
                                      setState(_reloadProducts);
                                    },
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Subtotal',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Text(
                                '${storePrice(total)} TND',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => context.push('${widget.basePath}/checkout'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Continue to Order', style: TextStyle(fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
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
