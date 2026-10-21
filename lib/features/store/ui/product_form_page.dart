import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../core/services/image_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/validators.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final int? productId;

  const ProductFormPage({super.key, this.productId});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
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
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit product' : 'Add product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !admin
              ? const Center(child: Text('Administrator access is required.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width > 760 ? 680 : 620),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextFormField(
                            controller: _title,
                            maxLength: 80,
                            decoration: const InputDecoration(labelText: 'Product name'),
                            validator: (value) => Validators.requiredText(value ?? '', 'the product name'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _description,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 500,
                            decoration: const InputDecoration(labelText: 'Description'),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: const [
                              DropdownMenuItem(value: 'training_gear', child: Text('Training gear')),
                              DropdownMenuItem(value: 'supplement', child: Text('Supplement')),
                            ],
                            onChanged: (value) => setState(() => _category = value ?? _category),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _price,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Price (TND)'),
                                  validator: (value) {
                                    final number = double.tryParse((value ?? '').replaceAll(',', '.'));
                                    return number == null || number < 0 ? 'Enter a non-negative price.' : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _stock,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Stock'),
                                  validator: (value) {
                                    final number = int.tryParse(value ?? '');
                                    return number == null || number < 0 ? 'Enter a non-negative stock.' : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final path in _imagePaths)
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildImagePreview(path),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton.filledTonal(
                                        tooltip: 'Remove photo',
                                        onPressed: () => setState(() => _imagePaths.remove(path)),
                                        icon: const Icon(Icons.close, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              if (_imagePaths.length < 3)
                                OutlinedButton.icon(
                                  onPressed: _pickImages,
                                  icon: const Icon(Icons.add_photo_alternate_outlined),
                                  label: Text('Add photos (${_imagePaths.length}/3)'),
                                ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Save product'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildImagePreview(String path) {
    if (path.startsWith('data:image/')) {
      // Base64 image (web)
      try {
        final base64String = path.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(bytes, width: 76, height: 76, fit: BoxFit.cover);
      } catch (e) {
        return Container(
          width: 76,
          height: 76,
          color: Colors.grey,
          child: const Icon(Icons.error),
        );
      }
    } else {
      // File path (mobile)
      return Image.file(File(path), width: 76, height: 76, fit: BoxFit.cover);
    }
  }
}
