import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/review_models.dart';
import '../data/store_cart.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'contact_seller_page.dart';
import 'product_reviews_page.dart';
import 'store_widgets.dart';

class ProductDetailsPage extends ConsumerStatefulWidget {
  final int productId;
  final String basePath;
  final bool allowBuying;

  const ProductDetailsPage({
    super.key,
    required this.productId,
    required this.basePath,
    this.allowBuying = true,
  });

  @override
  ConsumerState<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends ConsumerState<ProductDetailsPage> {
  final _repository = StoreRepository();
  late Future<StoreProduct?> _product;
  late Future<ProductRating> _rating;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _product = _repository.publicProductById(widget.productId);
    _rating = _repository.getProductRating(widget.productId);
  }

  void _addToCart(StoreProduct product) {
    final added = ref.read(storeCartProvider.notifier).add(product, quantity: _quantity);
    if (!added) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The cart quantity exceeds available stock.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Added to cart.'),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () => context.push('${widget.basePath}/cart'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        actions: widget.allowBuying
            ? [
                IconButton(
                  tooltip: 'Cart',
                  onPressed: () => context.push('${widget.basePath}/cart'),
                  icon: const Icon(Icons.shopping_cart_outlined),
                ),
              ]
            : null,
      ),
      body: FutureBuilder<StoreProduct?>(
        future: _product,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Product unavailable',
              message: 'Could not load this product.',
            );
          }
          final product = snapshot.data;
          if (product == null) {
            return const StoreMessage(
              icon: Icons.search_off,
              title: 'Product not found',
              message: 'This product may have been removed.',
            );
          }
          final isOfficial = product.source == 'app_store';
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width > 800 ? 720 : 620),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _gallery(product),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.title,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${storePrice(product.priceTnd)} TND',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.deepBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _tag(storeCategoryLabel(product.category)),
                            if (!isOfficial) _tag(product.condition == 'used' ? 'Used' : 'New'),
                            _tag(product.isAvailable ? '${product.stock} available' : 'Unavailable'),
                          ],
                        ),
                        if (product.sellerName != null) ...[
                          const SizedBox(height: 14),
                          Text('Seller: ${product.sellerName}'),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          product.description.isEmpty ? 'No description provided.' : product.description,
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
                        ),
                        const SizedBox(height: 20),
                        _buildReviewsSummary(),
                        if (isOfficial && product.isAvailable) ...[
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              IconButton(
                                tooltip: 'Decrease quantity',
                                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.w700)),
                              IconButton(
                                tooltip: 'Increase quantity',
                                onPressed: _quantity < product.stock ? () => setState(() => _quantity++) : null,
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isOfficial && widget.allowBuying)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                builder: (context) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: MediaQuery.of(context).viewInsets.bottom,
                                  ),
                                  child: ContactSellerPage(product: product),
                                ),
                              );
                            },
                            icon: const Icon(Icons.message_outlined),
                            label: const Text('Contact seller'),
                          ),
                        ),
                      ),
                    ),
                  if (isOfficial && widget.allowBuying)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: product.isAvailable ? () => _addToCart(product) : null,
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(product.isAvailable ? 'Add to cart' : 'Out of stock'),
                          ),
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

  Widget _gallery(StoreProduct product) {
    final images = product.imagePaths;
    if (images.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1.65,
        child: StoreProductImage(paths: [], size: double.infinity),
      );
    }
    return SizedBox(
      height: 260,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => StoreProductImage(
          paths: [images[index]],
          size: double.infinity,
        ),
      ),
    );
  }

  Widget _tag(String text) => Chip(
        label: Text(text),
        backgroundColor: AppColors.softBlue,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );

  Widget _buildReviewsSummary() {
    return FutureBuilder<ProductRating>(
      future: _rating,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final rating = snapshot.data!;

        if (rating.totalReviews == 0) {
          return Card(
            elevation: 0,
            color: AppColors.softBlue,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductReviewsPage(productId: widget.productId),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.rate_review_outlined, color: AppColors.textSecondary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No reviews yet. Be the first to review!',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          color: AppColors.softBlue,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductReviewsPage(productId: widget.productId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rating.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(5, (index) {
                            if (index < rating.averageRating.floor()) {
                              return const Icon(Icons.star, size: 18, color: Colors.amber);
                            } else if (index < rating.averageRating) {
                              return const Icon(Icons.star_half, size: 18, color: Colors.amber);
                            } else {
                              return const Icon(Icons.star_border, size: 18, color: Colors.amber);
                            }
                          }),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rating.totalReviews} ${rating.totalReviews == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Column(
                    children: [
                      Text(
                        'See all reviews',
                        style: TextStyle(
                          color: AppColors.deepBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.deepBlue),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
