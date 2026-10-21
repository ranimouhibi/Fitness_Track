import 'package:go_router/go_router.dart';

import 'ui/cart_page.dart';
import 'ui/checkout_page.dart';
import 'ui/my_listings_page.dart';
import 'ui/orders_page.dart';
import 'ui/product_details_page.dart';
import 'ui/product_form_page.dart';
import 'ui/sell_item_page.dart';
import 'ui/seller_contact_requests_page.dart';
import 'ui/store_admin_page.dart';
import 'ui/store_page.dart';
import 'ui/wishlist_page.dart';

final storeRoutes = storeRoutesFor('/store');

List<RouteBase> storeRoutesFor(String basePath, {bool admin = false}) => [
      GoRoute(
        path: basePath,
        builder: (_, _) => admin
            ? const StoreAdminPage()
            : StorePage(basePath: basePath),
      ),
      if (admin) ...[
        GoRoute(
          path: '$basePath/product/new',
          builder: (_, _) => const ProductFormPage(),
        ),
        GoRoute(
          path: '$basePath/product/:productId/edit',
          builder: (_, state) => ProductFormPage(
            productId: int.parse(state.pathParameters['productId']!),
          ),
        ),
        GoRoute(
          path: '$basePath/product/:productId',
          builder: (_, state) => ProductDetailsPage(
            productId: int.parse(state.pathParameters['productId']!),
            basePath: basePath,
            allowBuying: false,
          ),
        ),
      ] else ...[
        GoRoute(
          path: '$basePath/sell',
          builder: (_, _) => const SellItemPage(),
        ),
        GoRoute(
          path: '$basePath/sell/:productId',
          builder: (_, state) => SellItemPage(
            productId: int.parse(state.pathParameters['productId']!),
          ),
        ),
        GoRoute(
          path: '$basePath/product/:productId',
          builder: (_, state) => ProductDetailsPage(
            productId: int.parse(state.pathParameters['productId']!),
            basePath: basePath,
          ),
        ),
        GoRoute(
          path: '$basePath/cart',
          builder: (_, _) => CartPage(basePath: basePath),
        ),
        GoRoute(
          path: '$basePath/checkout',
          builder: (_, _) => CheckoutPage(basePath: basePath),
        ),
        GoRoute(
          path: '$basePath/orders',
          builder: (_, _) => OrdersPage(basePath: basePath),
        ),
        GoRoute(
          path: '$basePath/orders/:orderId',
          builder: (_, state) => OrderDetailsPage(
            orderId: int.parse(state.pathParameters['orderId']!),
          ),
        ),
        GoRoute(
          path: '$basePath/listings',
          builder: (_, _) => MyListingsPage(basePath: basePath),
        ),
        GoRoute(
          path: '$basePath/wishlist',
          builder: (_, _) => WishlistPage(basePath: basePath),
        ),
        GoRoute(
          path: '$basePath/contact-requests',
          builder: (_, _) => const SellerContactRequestsPage(),
        ),
      ],
    ];
