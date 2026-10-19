import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'store_models.dart';

class StoreCartNotifier extends Notifier<Map<int, int>> {
  @override
  Map<int, int> build() => const {};

  bool add(StoreProduct product, {int quantity = 1}) {
    if (!product.isAvailable || quantity < 1) return false;
    final next = (state[product.id] ?? 0) + quantity;
    if (next > product.stock) return false;
    state = {...state, product.id: next};
    return true;
  }

  bool setQuantity(StoreProduct product, int quantity) {
    if (quantity < 1) {
      remove(product.id);
      return true;
    }
    if (quantity > product.stock || !product.isAvailable) return false;
    state = {...state, product.id: quantity};
    return true;
  }

  void remove(int productId) {
    state = Map.from(state)..remove(productId);
  }

  void clear() => state = const {};
}

final storeCartProvider =
    NotifierProvider<StoreCartNotifier, Map<int, int>>(StoreCartNotifier.new);
