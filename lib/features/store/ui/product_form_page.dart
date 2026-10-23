import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/services/image_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

// Function to show the product form as a dialog
Future<bool?> showProductFormDialog(BuildContext context, {int? productId}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ProductFormDialog(productId: productId),
    ),
  );
}

class ProductFormDialog extends ConsumerStatefulWidget {
  final int? productId;

  const ProductFormDialog({super.key, this.productId});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _repository = StoreRepository();
  final List<String> _imagePaths = [];
  String _category = 'training_gear';
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadProduct();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    final user = ref.read(sessionProvider);
    if (user?.role != UserRole.admin) {
      setState(() {
        _error = 'Administrator access is required.';
        _loading = false;
      });
      return;
    }
    final product = await _repository.officialProductById(widget.productId!, user!.id);
    if (!mounted) return;
    if (product == null || product.source != 'app_store') {
      setState(() {
        _error = 'Official product not found.';
        _loading = false;
      });
      return;
    }
    _title.text = product.title;
    _description.text = product.description;
    _price.text = storePrice(product.priceTnd);
    _stock.text = '${product.stock}';
    _category = product.category;
    _imagePaths.addAll(product.imagePaths);
    setState(() => _loading = false);
  }

  Future<void> _pickImages() async {
    if (_imagePaths.length >= 3) return;
    final newPaths = await ImageService.instance.pickImages(limit: 3 - _imagePaths.length);
    if (mounted && newPaths.isNotEmpty) {
      setState(() => _imagePaths.addAll(newPaths));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(sessionProvider);
    if (user?.role != UserRole.admin) {
      setState(() => _error = 'Administrator access is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repository.saveOfficialProduct(
        id: widget.productId,
        adminId: user!.id,
        title: _title.text,
        description: _description.text,
        category: _category,
        priceTnd: double.parse(_price.text.trim().replaceAll(',', '.')),
        stock: int.parse(_stock.text.trim()),
        imagePaths: _imagePaths,
      );
      if (mounted) Navigator.pop(context, true);
    } on StoreException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not save this product. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(sessionProvider)?.role == UserRole.admin;
    final width = MediaQuery.sizeOf(context).width;
    
    return Container(
      constraints: BoxConstraints(
        maxWidth: width > 760 ? 700 : 600,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Modern header with gradient
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2F6BCB), Color(0xFF173B7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _editing ? Icons.edit_rounded : Icons.add_shopping_cart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editing ? 'Edit Product' : 'Add New Product',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _editing ? 'Update product details' : 'Fill in product information',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Flexible(
            child: _loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : !admin
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('Administrator access is required.'),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          shrinkWrap: true,
                          children: [
                            // Product name
                            _buildTextField(
                              controller: _title,
                              label: 'Product Name',
                              icon: Icons.inventory_2_rounded,
                              maxLength: 80,
                              validator: (value) => Validators.requiredText(value ?? '', 'the product name'),
                            ),
                            const SizedBox(height: 16),
                            
                            // Description
                            _buildTextField(
                              controller: _description,
                              label: 'Description',
                              icon: Icons.description_rounded,
                              minLines: 3,
                              maxLines: 5,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 16),
                            
                            // Category dropdown
                            Container(
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.2)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: DropdownButtonFormField<String>(
                                value: _category,
                                decoration: const InputDecoration(
                                  labelText: 'Category',
                                  prefixIcon: Icon(Icons.category_rounded),
                                  border: InputBorder.none,
                                ),
                                dropdownColor: Colors.white,
                                items: const [
                                  DropdownMenuItem(value: 'training_gear', child: Text('Training gear')),
                                  DropdownMenuItem(value: 'supplement', child: Text('Supplement')),
                                ],
                                onChanged: (value) => setState(() => _category = value ?? _category),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Price and Stock
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _price,
                                    label: 'Price (TND)',
                                    icon: Icons.attach_money_rounded,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (value) {
                                      final number = double.tryParse((value ?? '').replaceAll(',', '.'));
                                      return number == null || number < 0 ? 'Enter a valid price' : null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                    controller: _stock,
                                    label: 'Stock',
                                    icon: Icons.inventory_rounded,
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      final number = int.tryParse(value ?? '');
                                      return number == null || number < 0 ? 'Enter valid stock' : null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Images section
                            Text(
                              'Product Images (${_imagePaths.length}/3)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F6BCB),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final path in _imagePaths)
                                  Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.3), width: 2),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: _buildImagePreview(path),
                                        ),
                                      ),
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            tooltip: 'Remove photo',
                                            onPressed: () => setState(() => _imagePaths.remove(path)),
                                            icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_imagePaths.length < 3)
                                  InkWell(
                                    onTap: _pickImages,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF5F7FA),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Color(0xFF2F6BCB).withOpacity(0.3),
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_photo_alternate_rounded,
                                            color: Color(0xFF2F6BCB),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Add Photo',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2F6BCB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_rounded, color: Colors.red.shade700, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      side: BorderSide(color: Color(0xFF6B7280), width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving ? null : _save,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: Color(0xFF2F6BCB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _saving
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                _editing ? Icons.save_rounded : Icons.add_rounded,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _editing ? 'Save Changes' : 'Add Product',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? maxLength,
    int? minLines,
    int? maxLines,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF2F6BCB).withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        minLines: minLines,
        maxLines: maxLines ?? 1,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Color(0xFF2F6BCB)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          counterText: maxLength != null ? null : '',
        ),
      ),
    );
  }

  Widget _buildImagePreview(String path) {
    if (path.startsWith('data:image/')) {
      try {
        final base64String = path.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, width: 90, height: 90, fit: BoxFit.cover);
      } catch (e) {
        return Container(
          width: 90,
          height: 90,
          color: Colors.grey.shade300,
          child: const Icon(Icons.error, color: Colors.grey),
        );
      }
    } else {
      return Image.file(File(path), width: 90, height: 90, fit: BoxFit.cover);
    }
  }
}

// Keep the old page for backward compatibility but redirect to dialog
class ProductFormPage extends ConsumerWidget {
  final int? productId;

  const ProductFormPage({super.key, this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Immediately show dialog and pop when done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showProductFormDialog(context, productId: productId).then((result) {
        if (context.mounted) {
          Navigator.pop(context, result);
        }
      });
    });
    
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
