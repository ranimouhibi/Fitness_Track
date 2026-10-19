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
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
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
                        return StoreProductTile(
                          product: product,
                          statusLabel: 'Line total: ${storePrice(product.priceTnd * quantity)} TND',
                          action: Column(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease quantity',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      ref.read(storeCartProvider.notifier).setQuantity(product, quantity - 1);
                                      setState(_reloadProducts);
                                    },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('$quantity'),
                                  IconButton(
                                    tooltip: 'Increase quantity',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: quantity < product.stock
                                        ? () {
                                            ref.read(storeCartProvider.notifier).setQuantity(product, quantity + 1);
                                            setState(_reloadProducts);
                                          }
                                        : null,
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                              IconButton(
                                tooltip: 'Remove item',
                                onPressed: () {
                                  ref.read(storeCartProvider.notifier).remove(product.id);
                                  setState(_reloadProducts);
                                },
                                icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Subtotal  ${storePrice(total)} TND',
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          FilledButton(
                            onPressed: () => context.push('${widget.basePath}/checkout'),
                            child: const Text('Continue to order'),
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
