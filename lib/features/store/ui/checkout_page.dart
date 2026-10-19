import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_cart.dart';
import '../data/store_repository.dart';
import 'store_widgets.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final String basePath;

  const CheckoutPage({super.key, required this.basePath});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _repository = StoreRepository();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(sessionProvider);
    if (user == null) {
      setState(() => _error = 'Sign in before placing an order.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final orderId = await _repository.placeOrder(
        userId: user.id,
        buyerName: _name.text,
        phone: _phone.text,
        deliveryAddress: _address.text,
        quantities: ref.read(storeCartProvider),
      );
      ref.read(storeCartProvider.notifier).clear();
      if (mounted) context.go('${widget.basePath}/orders/$orderId');
    } on StoreException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'The order could not be saved. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(storeCartProvider);
    final user = ref.watch(sessionProvider);
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm order')),
      body: cart.isEmpty
          ? const StoreMessage(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart is empty',
              message: 'Add products before placing an order.',
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width > 800 ? 620 : 560),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Delivery details', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (value) => value == null || value.trim().length < 2
                            ? 'Enter your full name.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone number'),
                        validator: (value) => value == null || value.trim().length < 6
                            ? 'Enter a valid phone number.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Delivery address'),
                        validator: (value) => value == null || value.trim().length < 8
                            ? 'Enter a complete delivery address.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'This records an order request. No payment will be processed in the app.',
                          style: TextStyle(color: AppColors.deepBlue),
                        ),
                      ),
                      if (user == null) ...[
                        const SizedBox(height: 12),
                        const Text('Sign in to place this order.'),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Place order'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
