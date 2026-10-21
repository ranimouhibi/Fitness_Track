import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_cart.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import '../data/wishlist_provider.dart';
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Store'),
            Text(
              _community ? 'Buy and sell community gear' : 'Official FitTrack products',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'My wishlist',
            onPressed: () => context.push('${widget.basePath}/wishlist'),
            icon: Badge(
              isLabelVisible: wishlistCount > 0,
              label: Text('$wishlistCount'),
              child: const Icon(Icons.favorite_outline),
            ),
          ),
          IconButton(
            tooltip: 'Contact requests',
            onPressed: () => context.push('${widget.basePath}/contact-requests'),
            icon: const Icon(Icons.mail_outline),
          ),
          IconButton(
            tooltip: 'My orders',
            onPressed: () => context.push('${widget.basePath}/orders'),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'My listings',
            onPressed: () => context.push('${widget.basePath}/listings'),
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            tooltip: 'Cart ($cartCount)',
            onPressed: () => context.push('${widget.basePath}/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('App store')),
                        ButtonSegment(value: true, label: Text('Community')),
                      ],
                      selected: {_community},
                      onSelectionChanged: (selection) => setState(() {
                        _community = selection.first;
                        _category = null;
                        _condition = null;
                        _products = _loadProducts();
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _reload(),
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            _reload();
                          },
                          icon: const Icon(Icons.close),
                        ),
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _filterChip('All', null, _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                _filterChip('Training gear', 'training_gear', _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                _filterChip('Supplement', 'supplement', _category, (value) {
                                  _category = value;
                                  _reload();
                                }),
                                if (_community) ...[
                                  _filterChip('New', 'new', _condition, (value) {
                                    _condition = value;
                                    _reload();
                                  }),
                                  _filterChip('Used', 'used', _condition, (value) {
                                    _condition = value;
                                    _reload();
                                  }),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        DropdownButton<String>(
                          value: _sort,
                          underline: const SizedBox.shrink(),
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
                      ],
                    ),
                    if (_community) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('${widget.basePath}/sell'),
                          icon: const Icon(Icons.add),
                          label: const Text('Sell something'),
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
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    
    return Stack(
      children: [
        StoreProductTile(
          product: widget.product,
          onTap: widget.onTap,
          action: widget.onAddToCart != null
              ? FilledButton(
                  onPressed: widget.product.isAvailable ? widget.onAddToCart : null,
                  child: const Text('Add'),
                )
              : const Icon(Icons.chevron_right),
          statusLabel: widget.showCondition
              ? (widget.product.condition == 'used' ? 'Used' : 'New')
              : null,
          averageRating: _averageRating,
          totalReviews: _totalReviews,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            tooltip: isFavorite ? 'Remove from wishlist' : 'Add to wishlist',
            onPressed: () => ref.read(wishlistProvider.notifier).toggle(widget.product.id),
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_outline,
              color: isFavorite ? Colors.red : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
