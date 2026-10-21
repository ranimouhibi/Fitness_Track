import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

import '../../../core/services/image_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class SellItemPage extends ConsumerStatefulWidget {
  final int? productId;

  const SellItemPage({super.key, this.productId});

  @override
  ConsumerState<SellItemPage> createState() => _SellItemPageState();
}

class _SellItemPageState extends ConsumerState<SellItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _repository = StoreRepository();
  final List<String> _imagePaths = [];
  String _category = 'training_gear';
  String _condition = 'new';
  String? _error;
  bool _loading = false;
  bool _saving = false;

  bool get _editing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadExisting();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    final user = ref.read(sessionProvider);
    if (user == null) {
      setState(() {
        _error = 'Sign in to edit this listing.';
        _loading = false;
      });
      return;
    }
    final product = await _repository.ownCommunityListingById(widget.productId!, user.id);
    if (!mounted) return;
    if (product == null || product.sellerId != user.id || product.source != 'community') {
      setState(() {
        _error = 'This listing is not available to your account.';
        _loading = false;
      });
      return;
    }
    _title.text = product.title;
    _description.text = product.description;
    _price.text = storePrice(product.priceTnd);
    _quantity.text = '${product.stock}';
    _category = product.category;
    _condition = product.condition;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(sessionProvider);
    if (user == null) {
      setState(() => _error = 'Sign in to submit a listing.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final price = double.parse(_price.text.trim().replaceAll(',', '.'));
      final stock = int.parse(_quantity.text.trim());
      if (_editing) {
        await _repository.requestListingChange(
          productId: widget.productId!,
          userId: user.id,
          requestType: 'edit',
          payload: {
            'title': _title.text.trim(),
            'description': _description.text.trim(),
            'category': _category,
            'condition': _condition,
            'price_tnd': price,
            'stock': stock,
            'image_paths': _imagePaths.join('\n'),
          },
        );
      } else {
        await _repository.submitListing(
          userId: user.id,
          title: _title.text,
          description: _description.text,
          category: _category,
          condition: _condition,
          priceTnd: price,
          stock: stock,
          imagePaths: _imagePaths,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Edit request sent for review.' : 'Listing sent for admin approval.')),
      );
      context.pop(true);
    } on StoreException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not submit this listing. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Request listing edit' : 'Sell something')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('Sign in to sell an item.'))
              : Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: width > 760 ? 680 : 620),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (!_editing)
                            const Text(
                              'Reviewed by an admin before appearing in the community store.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _title,
                            maxLength: 80,
                            decoration: const InputDecoration(labelText: 'Title'),
                            validator: (value) => Validators.requiredText(value ?? '', 'the title'),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _description,
                            minLines: 3,
                            maxLines: 5,
                            maxLength: 500,
                            decoration: const InputDecoration(labelText: 'Description'),
                            validator: (value) => (value ?? '').trim().length < 10
                                ? 'Add at least 10 characters.'
                                : null,
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
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'new', label: Text('New')),
                              ButtonSegment(value: 'used', label: Text('Used')),
                            ],
                            selected: {_condition},
                            onSelectionChanged: (values) => setState(() => _condition = values.first),
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
                                    return number == null || number <= 0 ? 'Enter a positive price.' : null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _quantity,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Quantity'),
                                  validator: (value) {
                                    final number = int.tryParse(value ?? '');
                                    return number == null || number < 1 ? 'Enter at least 1.' : null;
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
                                      right: 0,
                                      top: 0,
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
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _saving ? null : _submit,
                            child: _saving
                                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text(_editing ? 'Send edit for approval' : 'Send to admin for approval'),
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
