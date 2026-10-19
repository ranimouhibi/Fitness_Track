class StoreProduct {
  final int id;
  final String title;
  final String description;
  final String category;
  final String condition;
  final double priceTnd;
  final int stock;
  final String source;
  final int? sellerId;
  final String status;
  final List<String> imagePaths;
  final String? reviewNote;
  final String? sellerName;
  final String? pendingRequestType;

  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.condition,
    required this.priceTnd,
    required this.stock,
    required this.source,
    required this.sellerId,
    required this.status,
    required this.imagePaths,
    required this.reviewNote,
    required this.sellerName,
    required this.pendingRequestType,
  });

  bool get isAvailable => stock > 0 && status == 'approved';

  factory StoreProduct.fromMap(Map<String, Object?> row) {
    final rawImages = row['image_paths'] as String?;
    return StoreProduct(
      id: row['id'] as int,
      title: row['title'] as String,
      description: row['description'] as String? ?? '',
      category: row['category'] as String,
      condition: row['condition'] as String,
      priceTnd: (row['price_tnd'] as num).toDouble(),
      stock: row['stock'] as int,
      source: row['source'] as String,
      sellerId: row['seller_id'] as int?,
      status: row['status'] as String,
      imagePaths: rawImages == null || rawImages.isEmpty
          ? const []
          : rawImages.split('\n').where((path) => path.isNotEmpty).toList(),
      reviewNote: row['review_note'] as String?,
      sellerName: row['seller_name'] as String?,
      pendingRequestType: row['pending_request_type'] as String?,
    );
  }
}

class StoreOrder {
  final int id;
  final String buyerName;
  final String phone;
  final String deliveryAddress;
  final double totalTnd;
  final String status;
  final String createdAt;
  final List<StoreOrderItem> items;

  const StoreOrder({
    required this.id,
    required this.buyerName,
    required this.phone,
    required this.deliveryAddress,
    required this.totalTnd,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory StoreOrder.fromMap(
    Map<String, Object?> row,
    List<StoreOrderItem> items,
  ) => StoreOrder(
        id: row['id'] as int,
        buyerName: row['buyer_name'] as String,
        phone: row['phone'] as String,
        deliveryAddress: row['delivery_address'] as String,
        totalTnd: (row['total_tnd'] as num).toDouble(),
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        items: items,
      );
}

class StoreOrderItem {
  final String productTitle;
  final double unitPriceTnd;
  final int quantity;
  final double lineTotalTnd;

  const StoreOrderItem({
    required this.productTitle,
    required this.unitPriceTnd,
    required this.quantity,
    required this.lineTotalTnd,
  });

  factory StoreOrderItem.fromMap(Map<String, Object?> row) => StoreOrderItem(
        productTitle: row['product_title'] as String,
        unitPriceTnd: (row['unit_price_tnd'] as num).toDouble(),
        quantity: row['quantity'] as int,
        lineTotalTnd: (row['line_total_tnd'] as num).toDouble(),
      );
}
