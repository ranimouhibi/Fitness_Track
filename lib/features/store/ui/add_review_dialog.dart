import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/store_repository.dart';

class AddReviewDialog extends StatefulWidget {
  final int productId;
  final int userId;

  const AddReviewDialog({
    super.key,
    required this.productId,
    required this.userId,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  final _repository = StoreRepository();
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    
    if (comment.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review must be at least 10 characters.')),
      );
      return;
    }

    if (comment.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review must not exceed 500 characters.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _repository.addReview(
        productId: widget.productId,
        userId: widget.userId,
        rating: _rating,
        comment: comment,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a Review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rating',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  iconSize: 36,
                  onPressed: _submitting ? null : () => setState(() => _rating = starValue),
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: starValue <= _rating ? Colors.amber : AppColors.textSecondary,
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your Review',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLines: 5,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Share your experience with this product...',
                border: OutlineInputBorder(),
                helperText: 'Minimum 10 characters',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
