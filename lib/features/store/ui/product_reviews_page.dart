import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../data/review_models.dart';
import '../data/store_repository.dart';
import 'add_review_dialog.dart';
import 'store_widgets.dart';

class ProductReviewsPage extends ConsumerStatefulWidget {
  final int productId;

  const ProductReviewsPage({super.key, required this.productId});

  @override
  ConsumerState<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends ConsumerState<ProductReviewsPage> {
  final _repository = StoreRepository();
  late Future<List<ProductReview>> _reviews;
  late Future<ProductRating> _rating;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _reviews = _repository.getReviews(widget.productId);
    _rating = _repository.getProductRating(widget.productId);
  }

  Future<void> _refresh() async {
    setState(() => _loadData());
  }

  Future<void> _addReview() async {
    final userId = ref.read(sessionProvider)?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to leave a review.')),
      );
      return;
    }

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AddReviewDialog(
        productId: widget.productId,
        userId: userId,
      ),
    );

    if (result == true) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reviews & Ratings'),
        actions: [
          IconButton(
            tooltip: 'Write a review',
            onPressed: _addReview,
            icon: const Icon(Icons.rate_review_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ProductRating>(
          future: _rating,
          builder: (context, ratingSnapshot) {
            if (ratingSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (ratingSnapshot.hasError) {
              return const StoreMessage(
                icon: Icons.error_outline,
                title: 'Error loading reviews',
                message: 'Could not load reviews.',
              );
            }

            final rating = ratingSnapshot.data!;

            return FutureBuilder<List<ProductReview>>(
              future: _reviews,
              builder: (context, reviewsSnapshot) {
                if (reviewsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (reviewsSnapshot.hasError) {
                  return const StoreMessage(
                    icon: Icons.error_outline,
                    title: 'Error loading reviews',
                    message: 'Could not load reviews.',
                  );
                }

                final reviews = reviewsSnapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Rating summary
                    _buildRatingSummary(rating),
                    const SizedBox(height: 24),
                    
                    // Reviews list
                    if (reviews.isEmpty) ...[
                      const StoreMessage(
                        icon: Icons.rate_review_outlined,
                        title: 'No reviews yet',
                        message: 'Be the first to review this product.',
                      ),
                    ] else ...[
                      const Text(
                        'Customer Reviews',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...reviews.map((review) => _ReviewCard(review: review)),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReview,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write Review'),
      ),
    );
  }

  Widget _buildRatingSummary(ProductRating rating) {
    return Card(
      elevation: 0,
      color: AppColors.softBlue,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        rating.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildStars(rating.averageRating),
                      const SizedBox(height: 4),
                      Text(
                        '${rating.totalReviews} ${rating.totalReviews == 1 ? 'review' : 'reviews'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      for (int i = 5; i >= 1; i--)
                        _buildRatingBar(
                          i,
                          rating.ratingCounts[i] ?? 0,
                          rating.totalReviews,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$stars',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, size: 14, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.white,
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, size: 20, color: Colors.amber);
        } else if (index < rating) {
          return const Icon(Icons.star_half, size: 20, color: Colors.amber);
        } else {
          return const Icon(Icons.star_border, size: 20, color: Colors.amber);
        }
      }),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue,
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: AppColors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${review.rating}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.comment,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        if (diff.inHours == 0) {
          return '${diff.inMinutes}m ago';
        }
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else if (diff.inDays < 30) {
        return '${(diff.inDays / 7).floor()}w ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }
}
