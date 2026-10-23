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
            Icon(Icons.inventory_2, color: Colors.white),
            SizedBox(width: 8),
            Text('Product Details'),
          ],
        ),
        actions: widget.allowBuying
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: 'Cart',
                    onPressed: () => context.push('${widget.basePath}/cart'),
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                  ),
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
                        Container(
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: _gallery(product),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(20),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.softBlue,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary, width: 1),
                                ),
                                child: Text(
                                  '${storePrice(product.priceTnd)} TND',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.softBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Seller: ${product.sellerName}',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product.description.isEmpty ? 'No description provided.' : product.description,
                                style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildReviewsSummary(),
                        if (isOfficial && product.isAvailable) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(20),
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
                            child: Row(
                              children: [
                                const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                const Spacer(),
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.softBlue,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Decrease quantity',
                                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                        icon: Icon(
                                          Icons.remove_circle,
                                          color: _quantity > 1 ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$_quantity',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Increase quantity',
                                        onPressed: _quantity < product.stock ? () => setState(() => _quantity++) : null,
                                        icon: Icon(
                                          Icons.add_circle,
                                          color: _quantity < product.stock ? AppColors.primary : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.message),
                            label: const Text('Contact Seller', style: TextStyle(fontSize: 16)),
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
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_shopping_cart),
                            label: Text(
                              product.isAvailable ? 'Add to Cart' : 'Out of Stock',
                              style: const TextStyle(fontSize: 16),
                            ),
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

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.softBlue,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
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
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProductReviewsPage(productId: widget.productId),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.softBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.rate_review, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No reviews yet. Be the first to review!',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          );
        }

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
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProductReviewsPage(productId: widget.productId),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          rating.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            if (index < rating.averageRating.floor()) {
                              return const Icon(Icons.star, size: 16, color: Colors.amber);
                            } else if (index < rating.averageRating) {
                              return const Icon(Icons.star_half, size: 16, color: Colors.amber);
                            } else {
                              return const Icon(Icons.star_border, size: 16, color: Colors.amber);
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer Reviews',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.primary, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
