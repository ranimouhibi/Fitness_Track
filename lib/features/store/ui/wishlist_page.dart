import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_cart.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../data/wishlist_provider.dart';
import 'store_widgets.dart';

class WishlistPage extends ConsumerStatefulWidget {
  final String basePath;

  const WishlistPage({super.key, required this.basePath});

  @override
  ConsumerState<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends ConsumerState<WishlistPage> {
  final _repository = StoreRepository();
  late Future<List<StoreProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts();
  }

  Future<List<StoreProduct>> _loadProducts() async {
    final wishlist = ref.read(wishlistProvider);
    if (wishlist.isEmpty) return [];
    
    final products = <StoreProduct>[];
    for (final id in wishlist) {
      final product = await _repository.publicProductById(id);
      if (product != null) products.add(product);
    }
    return products;
  }

  void _reload() => setState(() => _products = _loadProducts());

  void _addToCart(StoreProduct product) {
    final added = ref.read(storeCartProvider.notifier).add(product);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to cart.' : 'No more stock available.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wishlistProvider, (_, __) => _reload());
    final width = MediaQuery.sizeOf(context).width;
    final wishlistCount = ref.watch(wishlistProvider).length;

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
            const Icon(Icons.favorite, color: Colors.white),
            const SizedBox(width: 8),
            const Text('My Wishlist'),
            const SizedBox(width: 8),
            if (wishlistCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$wishlistCount',
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
              title: 'Wishlist unavailable',
              message: 'Could not load your wishlist.',
            );
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return const StoreMessage(
              icon: Icons.favorite_outline,
              title: 'Your wishlist is empty',
              message: 'Add products to your wishlist by tapping the heart icon.',
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width > 800 ? 720 : 640),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final isOfficial = product.source == 'app_store';
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
                      onTap: () => context.push('${widget.basePath}/product/${product.id}'),
                      action: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOfficial && product.isAvailable)
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.softBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                tooltip: 'Add to cart',
                                onPressed: () => _addToCart(product),
                                icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
                              ),
                            ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              tooltip: 'Remove from wishlist',
                              onPressed: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                              icon: const Icon(Icons.favorite, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
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
