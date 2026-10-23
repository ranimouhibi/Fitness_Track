import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_cart.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../data/wishlist_provider.dart';
import 'sell_item_page.dart';
import 'store_widgets.dart';

class StorePage extends ConsumerStatefulWidget {
  final String basePath;

  const StorePage({super.key, this.basePath = '/store'});

  @override
  ConsumerState<StorePage> createState() => _StorePageState();
}

class _StorePageState extends ConsumerState<StorePage> {
  final _repository = StoreRepository();
  final _search = TextEditingController();
  String? _category;
  String? _condition;
  String _sort = 'name';
  bool _community = false;
  late Future<List<StoreProduct>> _products;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<StoreProduct>> _loadProducts() => _community
      ? _repository.communityProducts(
          search: _search.text,
          category: _category,
          condition: _condition,
          sort: _sort,
        )
      : _repository.officialProducts(
          search: _search.text,
          category: _category,
          sort: _sort,
        );

  void _reload() => setState(() => _products = _loadProducts());

  void _openProduct(StoreProduct product) => context.push(
        '${widget.basePath}/product/${product.id}',
      );

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
    final cartCount = ref.watch(storeCartProvider).values.fold<int>(0, (a, b) => a + b);
    final wishlistCount = ref.watch(wishlistProvider).length;
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width > 900 ? 820.0 : 720.0;

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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: Icon(
                _community ? Icons.people_rounded : Icons.storefront_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FitTrack Store',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    _community ? 'Community Marketplace' : 'Official Products',
                    style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'My wishlist',
              onPressed: () => context.push('${widget.basePath}/wishlist'),
              icon: Badge(
                isLabelVisible: wishlistCount > 0,
                label: Text('$wishlistCount', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFF2F6BCB), size: 22),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Contact requests',
              onPressed: () => context.push('${widget.basePath}/contact-requests'),
              icon: const Icon(Icons.mail_rounded, color: Color(0xFF2F6BCB), size: 22),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'My orders',
              onPressed: () => context.push('${widget.basePath}/orders'),
              icon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2F6BCB), size: 22),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 4, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'My listings',
              onPressed: () => context.push('${widget.basePath}/listings'),
              icon: const Icon(Icons.sell_rounded, color: Color(0xFF2F6BCB), size: 22),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Cart',
              onPressed: () => context.push('${widget.basePath}/cart'),
              icon: Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount', style: const TextStyle(fontSize: 10)),
                child: const Icon(Icons.shopping_cart_rounded, color: Color(0xFF2F6BCB), size: 22),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Segmented button moderne
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF5F7FA), Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.3), width: 2),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: SegmentedButton<bool>(
                        style: SegmentedButton.styleFrom(
                          selectedBackgroundColor: Color(0xFF2F6BCB),
                          selectedForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Official Store', style: TextStyle(fontWeight: FontWeight.w700)),
                            icon: Icon(Icons.storefront_rounded, size: 20),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Community', style: TextStyle(fontWeight: FontWeight.w700)),
                            icon: Icon(Icons.people_rounded, size: 20),
                          ),
                        ],
                        selected: {_community},
                        onSelectionChanged: (selection) => setState(() {
                          _community = selection.first;
                          _category = null;
                          _condition = null;
                          _products = _loadProducts();
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar moderne
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.2), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF2F6BCB).withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _reload(),
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2F6BCB), size: 24),
                          suffixIcon: _search.text.isNotEmpty
                              ? IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    _reload();
                                  },
                                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Filters et tri
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _modernFilterChip('All', null, _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                _modernFilterChip('Training gear', 'training_gear', _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                _modernFilterChip('Supplement', 'supplement', _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                if (_community) ...[
                                  _modernFilterChip('New', 'new', _condition, (value) {
                                    _condition = value;
                                    _reload();
                                  }),
                                  _modernFilterChip('Used', 'used', _condition, (value) {
                                    _condition = value;
                                    _reload();
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.3)),
                          ),
                          child: DropdownButton<String>(
                            value: _sort,
                            underline: const SizedBox.shrink(),
                            icon: const Icon(Icons.sort_rounded, color: Color(0xFF2F6BCB), size: 20),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2F6BCB)),
                            items: const [
                              DropdownMenuItem(value: 'name', child: Text('Name')),
                              DropdownMenuItem(value: 'price_low', child: Text('Price ↑')),
                              DropdownMenuItem(value: 'price_high', child: Text('Price ↓')),
                              DropdownMenuItem(value: 'newest', child: Text('Newest')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _sort = value;
                                _products = _loadProducts();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_community) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () {
                            showSellItemDialog(context).then((result) {
                              if (result == true) _reload();
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Color(0xFF2F6BCB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          label: const Text('Sell Something', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<StoreProduct>>(
                  future: _products,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return StoreMessage(
                        icon: Icons.error_outline,
                        title: 'Store unavailable',
                        message: 'The catalog could not be loaded.',
                        onRetry: _reload,
                      );
                    }
                    final products = snapshot.data ?? const <StoreProduct>[];
                    if (products.isEmpty) {
                      return StoreMessage(
                        icon: Icons.inventory_2_outlined,
                        title: 'Nothing here yet',
                        message: _community
                            ? 'Approved community listings will appear here.'
                            : 'Official products will appear here when added by the admin.',
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async => _reload(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductTileWithWishlist(
                            product: product,
                            basePath: widget.basePath,
                            onTap: () => _openProduct(product),
                            onAddToCart: _community ? null : () => _addToCart(product),
                            showCondition: _community,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (_community)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Community posts are reviewed by an admin before they appear.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modernFilterChip(
    String label,
    String? value,
    String? selected,
    ValueChanged<String?> onChanged,
  ) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: value == selected ? Colors.white : Color(0xFF2F6BCB),
            ),
          ),
          selected: value == selected,
          onSelected: (_) => onChanged(value),
          backgroundColor: Color(0xFFF5F7FA),
          selectedColor: Color(0xFF2F6BCB),
          checkmarkColor: Colors.white,
          side: BorderSide(
            color: value == selected ? Color(0xFF2F6BCB) : Color(0xFF2F6BCB).withOpacity(0.3),
            width: 2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );

  Widget _filterChip(
    String label,
    String? value,
    String? selected,
    ValueChanged<String?> onChanged,
  ) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: value == selected,
          onSelected: (_) => onChanged(value),
        ),
      );

}

class _ProductTileWithWishlist extends ConsumerStatefulWidget {
  final StoreProduct product;
  final String basePath;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final bool showCondition;

  const _ProductTileWithWishlist({
    required this.product,
    required this.basePath,
    required this.onTap,
    this.onAddToCart,
    this.showCondition = false,
  });

  @override
  ConsumerState<_ProductTileWithWishlist> createState() => _ProductTileWithWishlistState();
}

class _ProductTileWithWishlistState extends ConsumerState<_ProductTileWithWishlist> {
  final _repository = StoreRepository();
  double? _averageRating;
  int? _totalReviews;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  Future<void> _loadRating() async {
    try {
      final rating = await _repository.getProductRating(widget.product.id);
      if (mounted && rating.totalReviews > 0) {
        setState(() {
          _averageRating = rating.averageRating;
          _totalReviews = rating.totalReviews;
        });
      }
    } catch (_) {
      // Ignore errors loading rating
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(wishlistProvider).contains(widget.product.id);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Wishlist button at the top right, properly positioned
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: isFavorite ? 'Remove from wishlist' : 'Add to wishlist',
                    onPressed: () => ref.read(wishlistProvider.notifier).toggle(widget.product.id),
                    icon: Icon(
                      isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                      color: isFavorite ? Colors.red : Color(0xFF6B7280),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
          // Product tile content
          StoreProductTile(
            product: widget.product,
            onTap: widget.onTap,
            action: widget.onAddToCart != null
                ? FilledButton.icon(
                    onPressed: widget.product.isAvailable ? widget.onAddToCart : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Color(0xFF2F6BCB),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart_rounded, size: 18),
                    label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2F6BCB)),
                  ),
            statusLabel: widget.showCondition
                ? (widget.product.condition == 'used' ? 'Used' : 'New')
                : null,
            averageRating: _averageRating,
            totalReviews: _totalReviews,
          ),
        ],
      ),
    );
  }
}
