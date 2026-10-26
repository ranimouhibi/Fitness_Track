import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/services/error_logger.dart';
import 'contact_request_model.dart';
import 'review_models.dart';
import 'store_models.dart';

class StoreModerationRequest {
  final int id;
  final String requestType;
  final StoreProduct product;
  final Map<String, dynamic> payload;
  final String submitterName;

  const StoreModerationRequest({
    required this.id,
    required this.requestType,
    required this.product,
    required this.payload,
    required this.submitterName,
  });
}

class StoreRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> _requireAdmin(DatabaseExecutor db, int userId) async {
    final rows = await db.query(
      'users',
      columns: ['role'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty || rows.first['role'] != 'admin') {
      throw const StoreException('Administrator access is required.');
    }
  }

  Future<void> _requireSeller(DatabaseExecutor db, int userId) async {
    final rows = await db.query(
      'users',
      columns: ['role', 'coach_status'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) throw const StoreException('Sign in to use the store.');
    final role = rows.first['role'];
    final approvedCoach = role == 'coach' && rows.first['coach_status'] == 'approved';
    if (role != 'user' && !approvedCoach) {
      throw const StoreException('Only users and approved coaches can sell items.');
    }
  }

  Future<List<StoreProduct>> officialProducts({
    String search = '',
    String? category,
    String sort = 'name',
    int limit = 50,
    int offset = 0,
    double? minPrice,
    double? maxPrice,
  }) async {
    final db = await _db;
    final whereConditions = <String>["source = 'app_store' AND status = 'approved'"];
    final whereArgs = <Object?>[];
    
    if (category != null) {
      whereConditions.add('category = ?');
      whereArgs.add(category);
    }
    if (search.trim().isNotEmpty) {
      whereConditions.add('(title LIKE ? OR description LIKE ?)');
      whereArgs.addAll(['%${search.trim()}%', '%${search.trim()}%']);
    }
    if (minPrice != null) {
      whereConditions.add('price_tnd >= ?');
      whereArgs.add(minPrice);
    }
    if (maxPrice != null) {
      whereConditions.add('price_tnd <= ?');
      whereArgs.add(maxPrice);
    }
    
    final rows = await db.query(
      'products',
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: _sortOrder(sort),
      limit: limit,
      offset: offset,
    );
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<List<StoreProduct>> communityProducts({
    String search = '',
    String? category,
    String? condition,
    String sort = 'newest',
    int limit = 50,
    int offset = 0,
    double? minPrice,
    double? maxPrice,
  }) async {
    final db = await _db;
    final where = StringBuffer("p.source = 'community' AND p.status = 'approved'");
    final args = <Object?>[];
    if (category != null) {
      where.write(' AND p.category = ?');
      args.add(category);
    }
    if (condition != null) {
      where.write(' AND p.condition = ?');
      args.add(condition);
    }
    if (search.trim().isNotEmpty) {
      where.write(' AND (p.title LIKE ? OR p.description LIKE ?)');
      args.addAll(['%${search.trim()}%', '%${search.trim()}%']);
    }
    if (minPrice != null) {
      where.write(' AND p.price_tnd >= ?');
      args.add(minPrice);
    }
    if (maxPrice != null) {
      where.write(' AND p.price_tnd <= ?');
      args.add(maxPrice);
    }
    final rows = await db.rawQuery('''
      SELECT p.*, COALESCE(u.first_name || ' ' || u.last_name, 'Seller') AS seller_name
      FROM products p
      LEFT JOIN users u ON u.id = p.seller_id
      WHERE $where
      ORDER BY ${_sortOrder(sort, prefix: 'p.')}
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<List<StoreProduct>> myListings(int userId) async {
    final db = await _db;
    await _requireSeller(db, userId);
    final rows = await db.rawQuery('''
      SELECT p.*,
        (SELECT cr.request_type
         FROM content_requests cr
         WHERE cr.target_table = 'products' AND cr.target_id = p.id AND cr.status = 'pending'
         ORDER BY cr.id DESC LIMIT 1) AS pending_request_type
      FROM products p
      WHERE p.source = 'community' AND p.seller_id = ?
      ORDER BY p.id DESC
    ''', [userId]);
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<StoreProduct?> publicProductById(int id) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: "id = ? AND status = 'approved'",
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : StoreProduct.fromMap(rows.first);
  }

  Future<StoreProduct?> officialProductById(int id, int adminId) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    final rows = await db.query(
      'products',
      where: "id = ? AND source = 'app_store'",
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : StoreProduct.fromMap(rows.first);
  }

  Future<StoreProduct?> ownCommunityListingById(int id, int userId) async {
    final db = await _db;
    await _requireSeller(db, userId);
    final rows = await db.query(
      'products',
      where: "id = ? AND source = 'community' AND seller_id = ?",
      whereArgs: [id, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : StoreProduct.fromMap(rows.first);
  }

  Future<List<StoreProduct>> officialProductsForAdmin({
    required int adminId,
    String search = '',
    String? category,
  }) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    final where = StringBuffer("source = 'app_store'");
    final args = <Object?>[];
    if (category != null) {
      where.write(' AND category = ?');
      args.add(category);
    }
    if (search.trim().isNotEmpty) {
      where.write(' AND (title LIKE ? OR description LIKE ?)');
      args.addAll(['%${search.trim()}%', '%${search.trim()}%']);
    }
    final rows = await db.query('products', where: where.toString(), whereArgs: args, orderBy: 'title');
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<void> saveOfficialProduct({
    int? id,
    required int adminId,
    required String title,
    required String description,
    required String category,
    required double priceTnd,
    required int stock,
    required List<String> imagePaths,
  }) async {
    try {
      final db = await _db;
      await _requireAdmin(db, adminId);
      
      // Validation stricte
      final trimmedTitle = title.trim();
      if (trimmedTitle.isEmpty || trimmedTitle.length < 3) {
        throw const StoreException('Title must be at least 3 characters.');
      }
      if (trimmedTitle.length > 80) {
        throw const StoreException('Title must not exceed 80 characters.');
      }
      if (!{'training_gear', 'supplement'}.contains(category)) {
        throw const StoreException('Invalid category.');
      }
      if (priceTnd < 0 || priceTnd > 999999) {
        throw const StoreException('Price must be between 0 and 999,999 TND.');
      }
      if (stock < 0 || stock > 999999) {
        throw const StoreException('Stock must be between 0 and 999,999.');
      }
      if (description.trim().length > 500) {
        throw const StoreException('Description must not exceed 500 characters.');
      }
      if (imagePaths.length > 3) {
        throw const StoreException('Maximum 3 images allowed.');
      }
      
      final values = <String, Object?>{
        'title': trimmedTitle,
        'description': description.trim(),
        'category': category,
        'condition': 'new',
        'price_tnd': priceTnd,
        'stock': stock,
        'image_paths': imagePaths.join('\n'),
        'source': 'app_store',
        'seller_id': adminId,
        'status': 'approved',
      };
      if (id == null) {
        await db.insert('products', values);
        ErrorLogger.instance.logSuccess('Official product created: $trimmedTitle');
      } else {
        final count = await db.update(
          'products',
          values,
          where: "id = ? AND source = 'app_store'",
          whereArgs: [id],
        );
        if (count == 0) throw const StoreException('Product not found.');
        ErrorLogger.instance.logSuccess('Official product updated: $trimmedTitle');
      }
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('saveOfficialProduct', e, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteOfficialProduct(int id, int adminId) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    await db.delete('products', where: "id = ? AND source = 'app_store'", whereArgs: [id]);
  }

  Future<void> submitListing({
    required int userId,
    required String title,
    required String description,
    required String category,
    required String condition,
    required double priceTnd,
    required int stock,
    required List<String> imagePaths,
  }) async {
    final db = await _db;
    await _requireSeller(db, userId);
    
    // Validation stricte
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty || trimmedTitle.length < 3) {
      throw const StoreException('Title must be at least 3 characters.');
    }
    if (trimmedTitle.length > 80) {
      throw const StoreException('Title must not exceed 80 characters.');
    }
    if (!{'training_gear', 'supplement'}.contains(category)) {
      throw const StoreException('Invalid category.');
    }
    if (!{'new', 'used'}.contains(condition)) {
      throw const StoreException('Invalid condition.');
    }
    if (priceTnd <= 0 || priceTnd > 999999) {
      throw const StoreException('Price must be between 0.01 and 999,999 TND.');
    }
    if (stock <= 0 || stock > 999999) {
      throw const StoreException('Stock must be between 1 and 999,999.');
    }
    if (description.trim().length < 10) {
      throw const StoreException('Description must be at least 10 characters.');
    }
    if (description.trim().length > 500) {
      throw const StoreException('Description must not exceed 500 characters.');
    }
    if (imagePaths.length > 3) {
      throw const StoreException('Maximum 3 images allowed.');
    }
    
    await db.transaction((txn) async {
      final productId = await txn.insert('products', {
        'title': trimmedTitle,
        'description': description.trim(),
        'category': category,
        'condition': condition,
        'price_tnd': priceTnd,
        'stock': stock,
        'image_paths': imagePaths.join('\n'),
        'source': 'community',
        'seller_id': userId,
        'status': 'pending',
      });
      await txn.insert('content_requests', {
        'request_type': 'create',
        'target_table': 'products',
        'target_id': productId,
        'payload': jsonEncode({'title': trimmedTitle}),
        'submitted_by': userId,
        'status': 'pending',
      });
    });
  }

  Future<void> requestListingChange({
    required int productId,
    required int userId,
    required String requestType,
    Map<String, dynamic> payload = const {},
  }) async {
    if (!{'edit', 'delete'}.contains(requestType)) {
      throw const StoreException('Unsupported listing request.');
    }
    final db = await _db;
    await _requireSeller(db, userId);
    final products = await db.query(
      'products',
      columns: ['id'],
      where: "id = ? AND source = 'community' AND seller_id = ? AND status IN ('approved', 'refused')",
      whereArgs: [productId, userId],
      limit: 1,
    );
    if (products.isEmpty) throw const StoreException('This listing cannot be changed.');
    await db.transaction((txn) async {
      final pending = await txn.query(
        'content_requests',
        columns: ['id'],
        where: "target_table = 'products' AND target_id = ? AND status = 'pending'",
        whereArgs: [productId],
        limit: 1,
      );
      if (pending.isNotEmpty) {
        throw const StoreException('A request for this listing is already pending.');
      }
      await txn.insert('content_requests', {
        'request_type': requestType,
        'target_table': 'products',
        'target_id': productId,
        'payload': jsonEncode(payload),
        'submitted_by': userId,
        'status': 'pending',
      });
    });
  }

  Future<bool> cancelOwnPendingListing(int productId, int userId) async {
    final db = await _db;
    await _requireSeller(db, userId);
    return db.transaction<bool>((txn) async {
      final rows = await txn.query(
        'products',
        columns: ['id'],
        where: "id = ? AND source = 'community' AND seller_id = ? AND status = 'pending'",
        whereArgs: [productId, userId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      await txn.delete(
        'content_requests',
        where: "target_table = 'products' AND target_id = ? AND submitted_by = ? AND status = 'pending'",
        whereArgs: [productId, userId],
      );
      await txn.delete('products', where: 'id = ?', whereArgs: [productId]);
      return true;
    });
  }

  Future<List<StoreModerationRequest>> pendingCommunityRequests(int adminId) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    final rows = await db.rawQuery('''
      SELECT cr.id AS request_id, cr.request_type, cr.target_id, cr.payload,
             p.*, COALESCE(u.first_name || ' ' || u.last_name, 'Seller') AS seller_name
      FROM content_requests cr
      JOIN products p ON p.id = cr.target_id
      LEFT JOIN users u ON u.id = cr.submitted_by
      WHERE cr.target_table = 'products' AND cr.status = 'pending'
      ORDER BY cr.id DESC
    ''');
    return [
      for (final row in rows)
        StoreModerationRequest(
          id: row['request_id'] as int,
          requestType: row['request_type'] as String,
          product: StoreProduct.fromMap(row),
          payload: row['payload'] == null
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(jsonDecode(row['payload'] as String) as Map),
          submitterName: row['seller_name'] as String,
        ),
    ];
  }

  Future<void> decideCommunityRequest({
    required StoreModerationRequest request,
    required int adminId,
    required bool accept,
    String reviewNote = '',
  }) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    await db.transaction((txn) async {
      final requests = await txn.query(
        'content_requests',
        columns: ['id'],
        where: "id = ? AND target_table = 'products' AND status = 'pending'",
        whereArgs: [request.id],
        limit: 1,
      );
      if (requests.isEmpty) throw const StoreException('This request was already reviewed.');

      if (request.requestType == 'create') {
        await txn.update(
          'products',
          {
            'status': accept ? 'approved' : 'refused',
            'review_note': reviewNote.trim().isEmpty ? null : reviewNote.trim(),
          },
          where: "id = ? AND source = 'community'",
          whereArgs: [request.product.id],
        );
      } else if (request.requestType == 'edit' && accept) {
        final price = request.payload['price_tnd'];
        final stock = request.payload['stock'];
        if ((request.payload['title'] as String? ?? '').trim().isEmpty ||
            !{'training_gear', 'supplement'}.contains(request.payload['category']) ||
            !{'new', 'used'}.contains(request.payload['condition']) ||
            price is! num ||
            price <= 0 ||
            stock is! int ||
            stock < 0) {
          throw const StoreException('The proposed listing changes are invalid.');
        }
        final allowed = <String>{'title', 'description', 'category', 'condition', 'price_tnd', 'stock', 'image_paths'};
        final changes = Map<String, Object?>.fromEntries(
          request.payload.entries
              .where((entry) => allowed.contains(entry.key))
              .map((entry) => MapEntry(entry.key, entry.value)),
        );
        if (changes.isNotEmpty) {
          await txn.update('products', changes, where: "id = ? AND source = 'community'", whereArgs: [request.product.id]);
        }
        await txn.update(
          'products',
          {'status': 'approved', 'review_note': null},
          where: 'id = ?',
          whereArgs: [request.product.id],
        );
      } else if (request.requestType == 'delete' && accept) {
        await txn.delete(
          'products',
          where: "id = ? AND source = 'community' AND seller_id = ?",
          whereArgs: [request.product.id, request.product.sellerId],
        );
      } else if (!accept && request.requestType != 'create') {
        await txn.update(
          'products',
          {'review_note': reviewNote.trim().isEmpty ? 'Your request was declined.' : reviewNote.trim()},
          where: 'id = ?',
          whereArgs: [request.product.id],
        );
      }

      await txn.update(
        'content_requests',
        {
          'status': accept ? 'accepted' : 'refused',
          'decided_by': adminId,
          'payload': jsonEncode({...request.payload, 'review_note': reviewNote.trim()}),
        },
        where: 'id = ?',
        whereArgs: [request.id],
      );
    });
  }

  Future<int> placeOrder({
    required int userId,
    required String buyerName,
    required String phone,
    required String deliveryAddress,
    required Map<int, int> quantities,
  }) async {
    if (quantities.isEmpty) throw const StoreException('Your cart is empty.');
    if (buyerName.trim().length < 2 ||
        phone.trim().length < 6 ||
        deliveryAddress.trim().length < 8) {
      throw const StoreException('Enter valid delivery details before placing the order.');
    }
    final db = await _db;
    return db.transaction<int>((txn) async {
      final userRows = await txn.query('users', columns: ['role'], where: 'id = ?', whereArgs: [userId], limit: 1);
      if (userRows.isEmpty || !{'user', 'coach'}.contains(userRows.first['role'])) {
        throw const StoreException('Sign in with a user or coach account to order.');
      }
      final products = <StoreProduct>[];
      var total = 0.0;
      for (final entry in quantities.entries) {
        if (entry.value < 1) throw const StoreException('Quantity must be at least one.');
        final rows = await txn.query(
          'products',
          where: "id = ? AND source = 'app_store' AND status = 'approved'",
          whereArgs: [entry.key],
          limit: 1,
        );
        if (rows.isEmpty) throw const StoreException('A product is no longer available.');
        final product = StoreProduct.fromMap(rows.first);
        if (entry.value > product.stock) {
          throw StoreException('Only ${product.stock} ${product.title} available.');
        }
        products.add(product);
        total += product.priceTnd * entry.value;
      }
      final orderId = await txn.insert('store_orders', {
        'user_id': userId,
        'buyer_name': buyerName.trim(),
        'phone': phone.trim(),
        'delivery_address': deliveryAddress.trim(),
        'total_tnd': total,
        'status': 'placed',
      });
      for (var index = 0; index < products.length; index++) {
        final product = products[index];
        final quantity = quantities[product.id]!;
        final changed = await txn.rawUpdate(
          "UPDATE products SET stock = stock - ? WHERE id = ? AND stock >= ? AND source = 'app_store' AND status = 'approved'",
          [quantity, product.id, quantity],
        );
        if (changed != 1) throw StoreException('Stock changed for ${product.title}. Please retry.');
        await txn.insert('store_order_items', {
          'order_id': orderId,
          'product_id': product.id,
          'product_title': product.title,
          'unit_price_tnd': product.priceTnd,
          'quantity': quantity,
          'line_total_tnd': product.priceTnd * quantity,
        });
      }
      return orderId;
    });
  }

  Future<List<StoreOrder>> ordersForUser(int userId) async {
    final db = await _db;
    final rows = await db.query('store_orders', where: 'user_id = ?', whereArgs: [userId], orderBy: 'id DESC');
    return [for (final row in rows) await _orderFromRow(db, row)];
  }

  Future<List<StoreOrder>> allOrders({String? statusFilter}) async {
    final db = await _db;
    final where = statusFilter == null ? null : 'status = ?';
    final whereArgs = statusFilter == null ? null : [statusFilter];
    final rows = await db.query(
      'store_orders',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'id DESC',
    );
    return [for (final row in rows) await _orderFromRow(db, row)];
  }

  Future<void> updateOrderStatus(int orderId, String newStatus, int adminId) async {
    final db = await _db;
    await _requireAdmin(db, adminId);
    if (!{'placed', 'processing', 'completed', 'cancelled'}.contains(newStatus)) {
      throw const StoreException('Invalid order status.');
    }
    final count = await db.update(
      'store_orders',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [orderId],
    );
    if (count == 0) throw const StoreException('Order not found.');
  }

  Future<StoreOrder?> orderForUser(int orderId, int userId) async {
    final db = await _db;
    final rows = await db.query(
      'store_orders',
      where: 'id = ? AND user_id = ?',
      whereArgs: [orderId, userId],
      limit: 1,
    );
    return rows.isEmpty ? null : _orderFromRow(db, rows.first);
  }

  Future<StoreOrder?> orderById(int orderId) async {
    final db = await _db;
    final rows = await db.query(
      'store_orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    return rows.isEmpty ? null : _orderFromRow(db, rows.first);
  }

  Future<List<StoreProduct>> publicProducts({String? searchTerm}) async {
    final db = await _db;
    final whereConditions = <String>["status = 'approved'"];
    final whereArgs = <Object?>[];
    
    if (searchTerm != null && searchTerm.trim().isNotEmpty) {
      whereConditions.add('(title LIKE ? OR description LIKE ?)');
      whereArgs.addAll(['%${searchTerm.trim()}%', '%${searchTerm.trim()}%']);
    }
    
    final rows = await db.query(
      'products',
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'title COLLATE NOCASE',
      limit: 50,
    );
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<StoreOrder> _orderFromRow(DatabaseExecutor db, Map<String, Object?> row) async {
    final itemRows = await db.query(
      'store_order_items',
      where: 'order_id = ?',
      whereArgs: [row['id']],
      orderBy: 'id',
    );
    return StoreOrder.fromMap(row, itemRows.map(StoreOrderItem.fromMap).toList());
  }

  String _sortOrder(String sort, {String prefix = ''}) => switch (sort) {
        'price_low' => '${prefix}price_tnd ASC, ${prefix}title COLLATE NOCASE',
        'price_high' => '${prefix}price_tnd DESC, ${prefix}title COLLATE NOCASE',
        'newest' => '${prefix}id DESC',
        _ => '${prefix}title COLLATE NOCASE ASC',
      };

  Future<StoreStats> getStats() async {
    final db = await _db;
    
    // Count official products
    final officialResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE source = 'app_store'"
    );
    final totalOfficialProducts = officialResult.first['count'] as int;
    
    // Count community products
    final communityResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE source = 'community' AND status = 'approved'"
    );
    final totalCommunityProducts = communityResult.first['count'] as int;
    
    // Count orders by status
    final ordersResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'placed' THEN 1 ELSE 0 END) as placed,
        SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END) as processing,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled,
        SUM(total_tnd) as revenue
      FROM store_orders
    ''');
    final ordersRow = ordersResult.first;
    
    // Low stock count
    final lowStockResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE source = 'app_store' AND stock > 0 AND stock <= 5"
    );
    final lowStockCount = lowStockResult.first['count'] as int;
    
    // Out of stock count
    final outOfStockResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM products WHERE source = 'app_store' AND stock = 0"
    );
    final outOfStockCount = outOfStockResult.first['count'] as int;
    
    // Pending requests
    final pendingResult = await db.rawQuery(
      "SELECT COUNT(*) as count FROM content_requests WHERE target_table = 'products' AND status = 'pending'"
    );
    final pendingRequests = pendingResult.first['count'] as int;
    
    return StoreStats(
      totalOfficialProducts: totalOfficialProducts,
      totalCommunityProducts: totalCommunityProducts,
      totalOrders: ordersRow['total'] as int? ?? 0,
      totalRevenue: (ordersRow['revenue'] as num?)?.toDouble() ?? 0.0,
      ordersPlaced: ordersRow['placed'] as int? ?? 0,
      ordersProcessing: ordersRow['processing'] as int? ?? 0,
      ordersCompleted: ordersRow['completed'] as int? ?? 0,
      ordersCancelled: ordersRow['cancelled'] as int? ?? 0,
      lowStockCount: lowStockCount,
      outOfStockCount: outOfStockCount,
      pendingRequests: pendingRequests,
    );
  }

  Future<void> sendContactRequest({
    required int productId,
    required int buyerId,
    required String buyerPhone,
    required String message,
  }) async {
    try {
      final db = await _db;
      
      // Validate
      if (buyerPhone.trim().length < 6) {
        throw const StoreException('Enter a valid phone number.');
      }
      
      // Check if product exists and is community
      final products = await db.query(
        'products',
        where: "id = ? AND source = 'community' AND status = 'approved'",
        whereArgs: [productId],
        limit: 1,
      );
      
      if (products.isEmpty) {
        throw const StoreException('This product is not available.');
      }
      
      // Store contact request in database
      await db.insert('contact_requests', {
        'product_id': productId,
        'buyer_id': buyerId,
        'buyer_phone': buyerPhone.trim(),
        'message': message.trim(),
        'status': 'pending',
      });
      
      ErrorLogger.instance.logSuccess(
        'Contact request created: Product $productId, Buyer $buyerId',
      );
      
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('sendContactRequest', e, stackTrace);
      rethrow;
    }
  }

  Future<List<ContactRequest>> getContactRequestsForSeller(int sellerId) async {
    try {
      final db = await _db;
      
      final rows = await db.rawQuery('''
        SELECT 
          cr.id,
          cr.product_id,
          cr.buyer_id,
          cr.buyer_phone,
          cr.message,
          cr.status,
          cr.created_at,
          p.title AS product_title,
          COALESCE(u.first_name || ' ' || u.last_name, 'Buyer') AS buyer_name
        FROM contact_requests cr
        JOIN products p ON p.id = cr.product_id
        LEFT JOIN users u ON u.id = cr.buyer_id
        WHERE p.seller_id = ? AND p.source = 'community'
        ORDER BY 
          CASE cr.status 
            WHEN 'pending' THEN 1
            WHEN 'contacted' THEN 2
            WHEN 'closed' THEN 3
          END,
          cr.created_at DESC
      ''', [sellerId]);
      
      return rows.map(ContactRequest.fromMap).toList();
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('getContactRequestsForSeller', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateContactRequestStatus(int requestId, String newStatus, int sellerId) async {
    try {
      final db = await _db;
      
      if (!{'pending', 'contacted', 'closed'}.contains(newStatus)) {
        throw const StoreException('Invalid status.');
      }
      
      // Verify the request belongs to seller's product
      final check = await db.rawQuery('''
        SELECT cr.id
        FROM contact_requests cr
        JOIN products p ON p.id = cr.product_id
        WHERE cr.id = ? AND p.seller_id = ? AND p.source = 'community'
      ''', [requestId, sellerId]);
      
      if (check.isEmpty) {
        throw const StoreException('Contact request not found.');
      }
      
      await db.update(
        'contact_requests',
        {'status': newStatus},
        where: 'id = ?',
        whereArgs: [requestId],
      );
      
      ErrorLogger.instance.logSuccess('Contact request $requestId updated to $newStatus');
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('updateContactRequestStatus', e, stackTrace);
      rethrow;
    }
  }

  Future<void> addReview({
    required int productId,
    required int userId,
    required int rating,
    required String comment,
  }) async {
    try {
      final db = await _db;
      
      // Validate
      if (rating < 1 || rating > 5) {
        throw const StoreException('Rating must be between 1 and 5.');
      }
      if (comment.trim().length < 10) {
        throw const StoreException('Review must be at least 10 characters.');
      }
      if (comment.trim().length > 500) {
        throw const StoreException('Review must not exceed 500 characters.');
      }
      
      // Check if product exists
      final products = await db.query(
        'products',
        where: "id = ? AND status = 'approved'",
        whereArgs: [productId],
        limit: 1,
      );
      
      if (products.isEmpty) {
        throw const StoreException('Product not found.');
      }
      
      // Insert or update review
      await db.insert(
        'product_reviews',
        {
          'product_id': productId,
          'user_id': userId,
          'rating': rating,
          'comment': comment.trim(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      ErrorLogger.instance.logSuccess('Review added for product $productId');
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('addReview', e, stackTrace);
      rethrow;
    }
  }

  Future<List<ProductReview>> getReviews(int productId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.*, COALESCE(u.first_name || ' ' || u.last_name, 'User') AS user_name
      FROM product_reviews r
      LEFT JOIN users u ON u.id = r.user_id
      WHERE r.product_id = ?
      ORDER BY r.created_at DESC
    ''', [productId]);
    return rows.map(ProductReview.fromMap).toList();
  }

  Future<ProductRating> getProductRating(int productId) async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT 
        AVG(rating) as avg_rating,
        COUNT(*) as total,
        SUM(CASE WHEN rating = 5 THEN 1 ELSE 0 END) as rating_5,
        SUM(CASE WHEN rating = 4 THEN 1 ELSE 0 END) as rating_4,
        SUM(CASE WHEN rating = 3 THEN 1 ELSE 0 END) as rating_3,
        SUM(CASE WHEN rating = 2 THEN 1 ELSE 0 END) as rating_2,
        SUM(CASE WHEN rating = 1 THEN 1 ELSE 0 END) as rating_1
      FROM product_reviews
      WHERE product_id = ?
    ''', [productId]);
    
    final row = result.first;
    final total = row['total'] as int? ?? 0;
    
    if (total == 0) {
      return const ProductRating(
        averageRating: 0,
        totalReviews: 0,
        ratingCounts: {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      );
    }
    
    return ProductRating(
      averageRating: (row['avg_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: total,
      ratingCounts: {
        5: row['rating_5'] as int? ?? 0,
        4: row['rating_4'] as int? ?? 0,
        3: row['rating_3'] as int? ?? 0,
        2: row['rating_2'] as int? ?? 0,
        1: row['rating_1'] as int? ?? 0,
      },
    );
  }
}

class StoreException implements Exception {
  final String message;
  const StoreException(this.message);
  @override
  String toString() => message;
}
