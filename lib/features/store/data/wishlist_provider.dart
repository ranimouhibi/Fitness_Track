import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';

class WishlistNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _loadWishlist();
    return const {};
  }

  Future<void> _loadWishlist() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('wishlist');
    state = rows.map((row) => row['product_id'] as int).toSet();
  }

  Future<void> toggle(int productId) async {
    final db = await DatabaseHelper.instance.database;
    if (state.contains(productId)) {
      await db.delete('wishlist', where: 'product_id = ?', whereArgs: [productId]);
      state = Set.from(state)..remove(productId);
    } else {
      await db.insert('wishlist', {'product_id': productId});
      state = Set.from(state)..add(productId);
    }
  }

  bool isFavorite(int productId) => state.contains(productId);
}

final wishlistProvider = NotifierProvider<WishlistNotifier, Set<int>>(WishlistNotifier.new);
