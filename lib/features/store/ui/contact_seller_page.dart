import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/store_models.dart';
import '../data/store_repository.dart';

class ContactSellerPage extends ConsumerStatefulWidget {
  final StoreProduct product;

  const ContactSellerPage({super.key, required this.product});

  @override
  ConsumerState<ContactSellerPage> createState() => _ContactSellerPageState();
}

class _ContactSellerPageState extends ConsumerState<ContactSellerPage> {
  final _formKey = GlobalKey<FormState>();
  final _message = TextEditingController();
  final _phone = TextEditingController();
  bool _sending = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(sessionProvider);
    if (user == null) {
      setState(() => _error = 'Sign in to contact the seller.');
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await StoreRepository().sendContactRequest(
        productId: widget.product.id,
        buyerId: user.id,
        buyerPhone: _phone.text.trim(),
        message: _message.text.trim(),
      );
      setState(() => _sent = true);
    } on StoreException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not send message. Please try again.');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final width = MediaQuery.sizeOf(context).width;

    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact seller')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'Message sent!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'The seller has received your contact information and will reach out to you.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Contact seller')),
      body: user == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text('Sign in to contact the seller.'),
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width > 760 ? 620 : 560),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        color: AppColors.softBlue,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              const Icon(Icons.sell_outlined, color: AppColors.deepBlue),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.product.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Seller: ${widget.product.sellerName ?? "Unknown"}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your contact information',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Your phone number',
                          helperText: 'The seller will contact you on this number',
                        ),
                        validator: (value) =>
                            value == null || value.trim().length < 6
                                ? 'Enter a valid phone number.'
                                : null,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Message (optional)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _message,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          hintText: 'Ask about availability, condition, delivery, etc.',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'The seller will receive your phone number and message to contact you directly.',
                                style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _sending ? null : _send,
                        child: _sending
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Send contact request'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
