class ProductReview {
  final int id;
  final int productId;
  final int userId;
  final String userName;
  final int rating;
  final String comment;
  final String createdAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReview.fromMap(Map<String, Object?> row) {
    return ProductReview(
      id: row['id'] as int,
      productId: row['product_id'] as int,
      userId: row['user_id'] as int,
      userName: row['user_name'] as String? ?? 'User',
      rating: row['rating'] as int,
      comment: row['comment'] as String? ?? '',
      createdAt: row['created_at'] as String,
    );
  }
}

class ProductRating {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingCounts; // {5: 10, 4: 5, 3: 2, 2: 1, 1: 0}

  const ProductRating({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingCounts,
  });
}
