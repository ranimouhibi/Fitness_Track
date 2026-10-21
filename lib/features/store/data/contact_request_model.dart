class ContactRequest {
  final int id;
  final int productId;
  final String productTitle;
  final int buyerId;
  final String buyerName;
  final String buyerPhone;
  final String message;
  final String status;
  final String createdAt;

  const ContactRequest({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory ContactRequest.fromMap(Map<String, Object?> row) {
    return ContactRequest(
      id: row['id'] as int,
      productId: row['product_id'] as int,
      productTitle: row['product_title'] as String? ?? '',
      buyerId: row['buyer_id'] as int,
      buyerName: row['buyer_name'] as String? ?? 'Buyer',
      buyerPhone: row['buyer_phone'] as String,
      message: row['message'] as String? ?? '',
      status: row['status'] as String,
      createdAt: row['created_at'] as String,
    );
  }

  bool get isPending => status == 'pending';
  bool get isContacted => status == 'contacted';
  bool get isClosed => status == 'closed';
}
