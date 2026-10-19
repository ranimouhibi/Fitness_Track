import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class MyListingsPage extends ConsumerStatefulWidget {
  final String basePath;

  const MyListingsPage({super.key, required this.basePath});

  @override
  ConsumerState<MyListingsPage> createState() => _MyListingsPageState();
}

class _MyListingsPageState extends ConsumerState<MyListingsPage> {
  final _repository = StoreRepository();
  late Future<List<StoreProduct>> _listings;

  @override
  void initState() {
    super.initState();
    _listings = _load();
  }

  Future<List<StoreProduct>> _load() {
    final user = ref.read(sessionProvider);
    return user == null ? Future.value(const []) : _repository.myListings(user.id);
  }

  void _reload() => setState(() => _listings = _load());

  Future<void> _cancel(StoreProduct product) async {
    final user = ref.read(sessionProvider);
    if (user == null) return;
    try {
      await _repository.cancelOwnPendingListing(product.id, user.id);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pending listing cancelled.')),
        );
      }
    } on StoreException catch (error) {
      _showError(error.message);
    }
  }

  Future<void> _requestRemoval(StoreProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request listing removal?'),
        content: const Text('The listing will remain visible until an admin reviews your request.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send request')),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = ref.read(sessionProvider);
    if (user == null) return;
    try {
      await _repository.requestListingChange(
        productId: product.id,
        userId: user.id,
        requestType: 'delete',
        payload: {'title': product.title},
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removal request sent to admin.')),
        );
      }
    } on StoreException catch (error) {
      _showError(error.message);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('My listings')),
      body: user == null
          ? const StoreMessage(
              icon: Icons.person_outline,
              title: 'Sign in required',
              message: 'Sign in to manage your listings.',
            )
          : FutureBuilder<List<StoreProduct>>(
              future: _listings,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const StoreMessage(
                    icon: Icons.error_outline,
                    title: 'Listings unavailable',
                    message: 'Could not load your listings.',
                  );
                }
                final listings = snapshot.data ?? const <StoreProduct>[];
                if (listings.isEmpty) {
                  return const StoreMessage(
                    icon: Icons.sell_outlined,
                    title: 'No listings yet',
                    message: 'Items you submit for review will appear here.',
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width > 850 ? 760 : 680),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: listings.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = listings[index];
                        final status = _listingStatus(product);
                        final pendingCreation = product.status == 'pending';
                        final hasPendingChange = product.pendingRequestType != null &&
                          product.pendingRequestType != 'create';
                        final canChange = !hasPendingChange &&
                          (product.status == 'approved' || product.status == 'refused');
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                StoreProductTile(
                                  product: product,
                                  statusLabel: status,
                                  onTap: () => context.push('${widget.basePath}/product/${product.id}'),
                                  action: canChange
                                      ? IconButton(
                                          tooltip: 'Request edit',
                                          onPressed: () => context.push('${widget.basePath}/sell/${product.id}').then((_) => _reload()),
                                          icon: const Icon(Icons.edit_outlined),
                                        )
                                      : pendingCreation
                                          ? IconButton(
                                              tooltip: 'Cancel pending listing',
                                              onPressed: () => _cancel(product),
                                              icon: const Icon(Icons.close),
                                            )
                                          : null,
                                ),
                                if (product.reviewNote != null && product.reviewNote!.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                                      child: Text(
                                        'Admin note: ${product.reviewNote}',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                if (canChange)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _requestRemoval(product),
                                      icon: const Icon(Icons.delete_outline),
                                      label: const Text('Request removal'),
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

String _listingStatus(StoreProduct product) {
  if (product.pendingRequestType == 'edit') return 'Edit pending approval';
  if (product.pendingRequestType == 'delete') return 'Removal pending approval';
  return switch (product.status) {
    'pending' => 'Pending approval',
    'refused' => 'Refused',
    'approved' => product.stock > 0 ? 'Published · Available' : 'Published · Sold out',
    _ => product.status,
  };
}
