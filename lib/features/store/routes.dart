import 'package:go_router/go_router.dart';
import 'ui/store_page.dart';
import 'ui/sell_item_page.dart';

final storeRoutes = <RouteBase>[
  GoRoute(path: '/store', builder: (_, __) => const StorePage()),
  GoRoute(path: '/store/sell', builder: (_, __) => const SellItemPage()),
];
