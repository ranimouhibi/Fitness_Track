import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class StoreAdminPage extends ConsumerStatefulWidget {
  const StoreAdminPage({super.key});

  @override
  ConsumerState<StoreAdminPage> createState() => _StoreAdminPageState();
}

class _StoreAdminPageState extends ConsumerState<StoreAdminPage> {
  final _repository = StoreRepository();
  final _search = TextEditingController();
  int _tab = 0;
  String? _category;
  late Future<List<StoreProduct>> _products;
  late Future<List<StoreModerationRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _products = _loadProducts();
    _requests = _loadRequests();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int? get _adminId {
    final user = ref.read(sessionProvider);
    return user?.role == UserRole.admin ? user!.id : null;
  }

  Future<List<StoreProduct>> _loadProducts() {
    final id = _adminId;
    return id == null
        ? Future.value(const [])
        : _repository.officialProductsForAdmin(
            adminId: id,
            search: _search.text,
            category: _category,
          );
  }

  Future<List<StoreModerationRequest>> _loadRequests() {
    final id = _adminId;
    return id == null ? Future.value(const []) : _repository.pendingCommunityRequests(id);
  }

  void _reload() {
    setState(() {
      _products = _loadProducts();
      _requests = _loadRequests();
    });
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteProduct(StoreProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('Remove ${product.title} from the official store?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    final adminId = _adminId;
    if (confirmed != true || adminId == null) return;
    try {
      await _repository.deleteOfficialProduct(product.id, adminId);
      _reload();
      _notify('Product deleted.');
    } on StoreException catch (error) {
      _notify(error.message);
    }
  }

  Future<void> _reviewRequest(StoreModerationRequest request, bool accept) async {
    final note = TextEditingController();
    final noteValue = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Approve request?' : 'Decline request?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_requestAction(request.requestType)} · ${request.product.title}'),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Review note (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, note.text.trim()),
            child: Text(accept ? 'Approve' : 'Decline'),
          ),
        ],
      ),
    );
    note.dispose();
    if (noteValue == null) return;
    final adminId = _adminId;
    if (adminId == null) return;
    try {
      await _repository.decideCommunityRequest(
        request: request,
        adminId: adminId,
        accept: accept,
        reviewNote: noteValue,
      );
      _reload();
      _notify(accept ? 'Request approved.' : 'Request declined.');
    } on StoreException catch (error) {
      _notify(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(sessionProvider)?.role == UserRole.admin;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store admin'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: !admin
          ? const StoreMessage(
              icon: Icons.lock_outline,
              title: 'Administrator access required',
              message: 'Sign in with an administrator account to manage the store.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width > 900 ? 820 : 720),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        children: [
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 0, label: Text('App store')),
                              ButtonSegment(value: 1, label: Text('Community review')),
                            ],
                            selected: {_tab},
                            onSelectionChanged: (value) => setState(() => _tab = value.first),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _reload(),
                            decoration: InputDecoration(
                              hintText: _tab == 0 ? 'Search official products' : 'Search requests',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _search.clear();
                                  _reload();
                                },
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),
                          if (_tab == 0) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String?>(
                              initialValue: _category,
                              decoration: const InputDecoration(labelText: 'Category'),
                              items: const [
                                DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                                DropdownMenuItem<String?>(value: 'training_gear', child: Text('Training gear')),
                                DropdownMenuItem<String?>(value: 'supplement', child: Text('Supplement')),
                              ],
                              onChanged: (value) {
                                _category = value;
                                _reload();
                              },
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => context.push('/admin/store/product/new').then((_) => _reload()),
                                icon: const Icon(Icons.add),
                                label: const Text('Add product'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: _tab == 0 ? _officialList() : _moderationList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _officialList() => FutureBuilder<List<StoreProduct>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Products unavailable',
              message: 'The official product list could not be loaded.',
            );
          }
          final products = snapshot.data ?? const <StoreProduct>[];
          if (products.isEmpty) {
            return const StoreMessage(
              icon: Icons.inventory_2_outlined,
              title: 'No official products',
              message: 'Add a product to start the official catalog.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = products[index];
              return StoreProductTile(
                product: product,
                onTap: () => context.push('/admin/store/product/${product.id}'),
                statusLabel: product.stock > 0 ? 'Official · in stock' : 'Official · out of stock',
                action: PopupMenuButton<String>(
                  tooltip: 'Product actions',
                  onSelected: (action) {
                    if (action == 'edit') {
                      context.push('/admin/store/product/${product.id}/edit').then((_) => _reload());
                    } else if (action == 'delete') {
                      _deleteProduct(product);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  child: const Icon(Icons.more_vert),
                ),
              );
            },
          );
        },
      );

  Widget _moderationList() => FutureBuilder<List<StoreModerationRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const StoreMessage(
              icon: Icons.error_outline,
              title: 'Requests unavailable',
              message: 'Could not load community moderation requests.',
            );
          }
          final query = _search.text.trim().toLowerCase();
          final requests = (snapshot.data ?? const <StoreModerationRequest>[])
              .where((request) => query.isEmpty ||
                  request.product.title.toLowerCase().contains(query) ||
                  request.submitterName.toLowerCase().contains(query))
              .toList();
          if (requests.isEmpty) {
            return const StoreMessage(
              icon: Icons.inbox_outlined,
              title: 'No requests to review',
              message: 'New community listings and change requests will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final request = requests[index];
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      StoreProductTile(
                        product: request.product,
                        statusLabel: '${_requestAction(request.requestType)} · ${request.product.condition}',
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                        child: Text('Submitted by ${request.submitterName}'),
                      ),
                      if (request.payload['description'] case final String description when description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(description, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _reviewRequest(request, false),
                              icon: const Icon(Icons.close),
                              label: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _reviewRequest(request, true),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
}

String _requestAction(String type) => switch (type) {
      'create' => 'New listing',
      'edit' => 'Edit request',
      'delete' => 'Removal request',
      _ => type,
    };
