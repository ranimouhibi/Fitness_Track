import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';
import 'product_form_page.dart';
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
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5A6577), Color(0xFF6B7280)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Store Admin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Product & review management', style: TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5A6577), size: 22),
            ),
          ),
          const SizedBox(width: 8),
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
                constraints: BoxConstraints(maxWidth: width > 900 ? 900 : 720),
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
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFF5F7FA), Colors.white],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.3), width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: SegmentedButton<int>(
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor: Color(0xFF2F6BCB),
                                selectedForegroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              segments: const [
                                ButtonSegment(
                                  value: 0,
                                  label: Text('Official Store', style: TextStyle(fontWeight: FontWeight.w700)),
                                  icon: Icon(Icons.storefront_rounded, size: 20),
                                ),
                                ButtonSegment(
                                  value: 1,
                                  label: Text('Community', style: TextStyle(fontWeight: FontWeight.w700)),
                                  icon: Icon(Icons.people_rounded, size: 20),
                                ),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (value) => setState(() => _tab = value.first),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.2), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF2F6BCB).withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _search,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _reload(),
                              decoration: InputDecoration(
                                hintText: _tab == 0 ? 'Search official products' : 'Search requests',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _search.text.isNotEmpty
                                    ? IconButton(
                                        tooltip: 'Clear search',
                                        onPressed: () {
                                          _search.clear();
                                          _reload();
                                        },
                                        icon: const Icon(Icons.close),
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                          if (_tab == 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.softBlue.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border.withOpacity(0.3)),
                              ),
                              child: DropdownButtonFormField<String?>(
                                value: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_outlined),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                                dropdownColor: Colors.white,
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Row(
                                      children: [
                                        Icon(Icons.list_alt, size: 18),
                                        SizedBox(width: 8),
                                        Text('All categories'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'training_gear',
                                    child: Row(
                                      children: [
                                        Icon(Icons.fitness_center, size: 18),
                                        SizedBox(width: 8),
                                        Text('Training gear'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'supplement',
                                    child: Row(
                                      children: [
                                        Icon(Icons.local_drink, size: 18),
                                        SizedBox(width: 8),
                                        Text('Supplement'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() => _category = value);
                                  _reload();
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  showProductFormDialog(context).then((result) {
                                    if (result == true) _reload();
                                  });
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Color(0xFF2F6BCB),
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w600)),
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              final inStock = product.stock > 0;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      inStock ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: inStock ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (inStock ? Colors.green : Colors.red).withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => context.push('/admin/store/product/${product.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.verified, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Official',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: inStock ? Colors.green.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: inStock ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          inStock ? Icons.check_circle : Icons.cancel,
                                          size: 14,
                                          color: inStock ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          inStock ? 'In stock' : 'Out of stock',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: inStock ? Colors.green.shade700 : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              StoreProductTile(
                                product: product,
                                onTap: () => context.push('/admin/store/product/${product.id}'),
                                statusLabel: '',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Product actions',
                          onSelected: (action) {
                            if (action == 'edit') {
                              showProductFormDialog(context, productId: product.id).then((result) {
                                if (result == true) _reload();
                              });
                            } else if (action == 'delete') {
                              _deleteProduct(product);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 8),
                                  Text('Edit'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.softBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.more_vert, color: AppColors.deepBlue),
                          ),
                        ),
                      ],
                    ),
                  ),
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
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final request = requests[index];
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white, AppColors.softBlue.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Request type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.08)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRequestIcon(request.requestType),
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _requestAction(request.requestType),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '· ${request.product.condition}',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Product tile
                      StoreProductTile(
                        product: request.product,
                        statusLabel: '',
                      ),
                      const SizedBox(height: 12),
                      // Submitter info
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Submitted by ${request.submitterName}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (request.payload['description'] case final String description when description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _reviewRequest(request, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade700),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _reviewRequest(request, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w600)),
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

IconData _getRequestIcon(String type) => switch (type) {
      'create' => Icons.add_circle_outline,
      'edit' => Icons.edit_outlined,
      'delete' => Icons.delete_outline,
      _ => Icons.help_outline,
    };
