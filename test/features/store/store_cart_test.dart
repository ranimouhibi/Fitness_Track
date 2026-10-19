import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fittrack/features/store/data/store_cart.dart';
import 'package:fittrack/features/store/data/store_models.dart';

void main() {
  group('StoreCartNotifier', () {
    late ProviderContainer container;
    late StoreCartNotifier cart;

    setUp(() {
      container = ProviderContainer();
      cart = container.read(storeCartProvider.notifier);
    });

    tearDown(() => container.dispose());

    test('adds available quantities and rejects quantities above stock', () {
      final product = _product(stock: 2);

      expect(cart.add(product), isTrue);
      expect(cart.add(product), isTrue);
      expect(cart.add(product), isFalse);
      expect(container.read(storeCartProvider), {product.id: 2});
    });

    test('rejects unavailable products and removes zero quantities', () {
      final product = _product(stock: 2);

      expect(cart.add(_product(stock: 0)), isFalse);
      expect(cart.setQuantity(product, 3), isFalse);
      expect(cart.setQuantity(product, 0), isTrue);
      expect(container.read(storeCartProvider), isEmpty);
    });
  });
}

StoreProduct _product({required int stock}) => StoreProduct(
      id: 7,
      title: 'Yoga mat',
      description: '',
      category: 'training_gear',
      condition: 'new',
      priceTnd: 15,
      stock: stock,
      source: 'app_store',
      sellerId: null,
      status: 'approved',
      imagePaths: const [],
      reviewNote: null,
      sellerName: null,
      pendingRequestType: null,
    );
