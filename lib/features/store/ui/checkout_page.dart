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
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Confirm Order'),
          ],
        ),
      ),
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.softBlue,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.local_shipping, color: AppColors.primary, size: 24),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Delivery Details',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.softBlue,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: TextFormField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Full name',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Icon(Icons.person, color: AppColors.primary),
                                ),
                                validator: (value) => value == null || value.trim().length < 2
                                    ? 'Enter your full name.'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.softBlue,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: TextFormField(
                                controller: _phone,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                                ),
                                validator: (value) => value == null || value.trim().length < 6
                                    ? 'Enter a valid phone number.'
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.softBlue,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: TextFormField(
                                controller: _address,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  labelText: 'Delivery address',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  prefixIcon: Icon(Icons.location_on, color: AppColors.primary),
                                ),
                                validator: (value) => value == null || value.trim().length < 8
                                    ? 'Enter a complete delivery address.'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.softBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This records an order request. No payment will be processed in the app.',
                                style: TextStyle(color: AppColors.deepBlue, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (user == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_outlined, color: Colors.red, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Sign in to place this order.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle),
                        label: const Text('Place Order', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
