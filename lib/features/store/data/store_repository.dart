import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
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
  }) async {
    final db = await _db;
    final rows = await db.query(
      'products',
      where: "source = 'app_store' AND status = 'approved'${category == null ? '' : ' AND category = ?'}${search.trim().isEmpty ? '' : ' AND (title LIKE ? OR description LIKE ?)'}",
      whereArgs: [
        ?category,
        if (search.trim().isNotEmpty) ...['%${search.trim()}%', '%${search.trim()}%'],
      ],
      orderBy: _sortOrder(sort),
    );
    return rows.map(StoreProduct.fromMap).toList();
  }

  Future<List<StoreProduct>> communityProducts({
    String search = '',
    String? category,
    String? condition,
    String sort = 'newest',
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
    final rows = await db.rawQuery('''
      SELECT p.*, COALESCE(u.first_name || ' ' || u.last_name, 'Seller') AS seller_name
      FROM products p
      LEFT JOIN users u ON u.id = p.seller_id
      WHERE $where
      ORDER BY ${_sortOrder(sort, prefix: 'p.')}
    ''', args);
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
    final db = await _db;
    await _requireAdmin(db, adminId);
    if (title.trim().isEmpty ||
      !{'training_gear', 'supplement'}.contains(category) ||
      priceTnd < 0 ||
      stock < 0) {
      throw const StoreException('Enter a title, a valid price and a non-negative stock.');
    }
    final values = <String, Object?>{
      'title': title.trim(),
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
    } else {
      final count = await db.update(
        'products',
        values,
        where: "id = ? AND source = 'app_store'",
        whereArgs: [id],
      );
      if (count == 0) throw const StoreException('Product not found.');
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
    if (title.trim().isEmpty || priceTnd <= 0 || stock <= 0) {
      throw const StoreException('Enter a title, positive price and available quantity.');
    }
    await db.transaction((txn) async {
      final productId = await txn.insert('products', {
        'title': title.trim(),
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
        'payload': jsonEncode({'title': title.trim()}),
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
}

class StoreException implements Exception {
  final String message;
  const StoreException(this.message);
  @override
  String toString() => message;
}
