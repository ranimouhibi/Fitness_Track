# 📚 Guide de Validation - Module Store

## 🏗️ ARCHITECTURE DU MODULE STORE

### 1. Structure Générale (Clean Architecture)

```
lib/features/store/
├── data/              # Couche de données (Data Layer)
│   ├── models         # Modèles de données
│   ├── providers      # Gestion d'état (Riverpod)
│   └── repository     # Accès aux données
├── ui/                # Couche présentation (UI Layer)
│   ├── pages          # Écrans de l'application
│   ├── dialogs        # Fenêtres modales
│   └── widgets        # Composants réutilisables
└── routes.dart        # Configuration du routage
```

### 2. Couche de Données (Data Layer)

#### **store_models.dart** - Modèles principaux
```dart
- StoreProduct      // Produit du magasin
- StoreOrder        // Commande client
- StoreOrderItem    // Item d'une commande
- StoreException    // Gestion des erreurs
```

#### **review_models.dart** - Système d'évaluation
```dart
- ProductReview     // Avis client sur un produit
- ProductRating     // Note moyenne et statistiques
```

#### **contact_request_model.dart** - Communication
```dart
- ContactRequest    // Demande de contact vendeur-acheteur
```

#### **qr_scanner_service.dart** - Scanner QR/Barcode
```dart
- QRScannerService  // Service pour scanner et générer QR codes
- Formats supportés: QR Code, EAN13, EAN8, Code128
- parseOrderQRCode() - Parse QR code commande
- parseProductBarcode() - Parse code-barres produit
- generateOrderQRContent() - Génère contenu QR commande
```

#### **store_repository.dart** - Accès base de données
- **Rôle**: Interface unique pour toutes les opérations base de données
- **Pattern**: Repository Pattern (abstraction de la source de données)
- **Méthodes principales**:
  - `publicProducts()` - Liste produits disponibles
  - `placeOrder()` - Créer une commande
  - `updateOrderStatus()` - Admin: changer statut commande
  - `addReview()` - Ajouter un avis
  - `sendContactRequest()` - Contacter un vendeur

#### **store_cart.dart** - Panier d'achat
```dart
Provider: storeCartProvider
Type: StateNotifierProvider<StoreCart, Map<int, int>>
État: Map<productId, quantity>
```

#### **wishlist_provider.dart** - Liste de souhaits
```dart
Provider: wishlistProvider
Type: StateNotifierProvider<Wishlist, Set<int>>
État: Set<productId>
```

### 3. Couche UI (Presentation Layer)

#### **Pages Utilisateur (User Role)**
1. **store_page.dart** - Page principale magasin
2. **product_details_page.dart** - Détails d'un produit
3. **cart_page.dart** - Panier d'achat
4. **checkout_page.dart** - Confirmation commande
5. **orders_page.dart** - Historique des commandes
6. **wishlist_page.dart** - Liste de souhaits
7. **my_listings_page.dart** - Mes produits en vente
8. **sell_item_page.dart** - Vendre un produit
9. **qr_scanner_page.dart** - Scanner QR/Barcode (📱 CAPTEUR LOCAL)
10. **qr_code_display_page.dart** - Afficher QR code commande

#### **Pages Admin (Admin Role)**
1. **store_admin_page.dart** - Gestion produits/demandes
2. **admin_orders_page.dart** - Gestion commandes
3. **store_stats_page.dart** - Statistiques du magasin
4. **seller_contact_requests_page.dart** - Demandes de contact

#### **Composants Réutilisables**
- **store_widgets.dart** - Widgets communs (StoreProductTile, StoreMessage, etc.)

---

## 💡 EXPLICATION DU CODE

### Pattern 1: State Management avec Riverpod

**Exemple - Panier d'achat (store_cart.dart)**
```dart
class StoreCart extends StateNotifier<Map<int, int>> {
  StoreCart() : super({});
  
  bool add(StoreProduct product, {int quantity = 1}) {
    final current = state[product.id] ?? 0;
    final newQuantity = current + quantity;
    
    if (newQuantity > product.stock) return false;
    
    state = {...state, product.id: newQuantity};
    return true;
  }
}

// Provider
final storeCartProvider = StateNotifierProvider<StoreCart, Map<int, int>>(
  (ref) => StoreCart(),
);
```

**Explication**:
- `StateNotifier` = Gère l'état mutable de façon immutable
- `state = {...state, ...}` = Crée une nouvelle Map (immutabilité)
- `ref.watch(storeCartProvider)` = Écoute les changements
- `ref.read(storeCartProvider.notifier)` = Accède aux méthodes

### Pattern 2: Repository Pattern

**Exemple - StoreRepository**
```dart
class StoreRepository {
  Future<List<StoreProduct>> publicProducts({
    String? category,
    String? searchTerm,
  }) async {
    final db = await DatabaseHelper().database;
    
    final where = <String>[];
    final args = <dynamic>[];
    
    where.add("status = 'approved'");
    if (category != null) {
      where.add("category = ?");
      args.add(category);
    }
    
    final results = await db.query(
      'store_products',
      where: where.join(' AND '),
      whereArgs: args,
    );
    
    return results.map((e) => StoreProduct.fromMap(e)).toList();
  }
}
```

**Avantages**:
- Séparation UI / Logique métier
- Facilite les tests unitaires
- Centralise l'accès aux données

### Pattern 3: Widget State avec ConsumerStatefulWidget

**Exemple - CartPage**
```dart
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key, required this.basePath});
  
  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(storeCartProvider);
    
    return Scaffold(
      body: FutureBuilder<List<StoreProduct>>(
        future: _products,
        builder: (context, snapshot) {
          // UI construction
        },
      ),
    );
  }
}
```

**Explication**:
- `ConsumerStatefulWidget` = Accès à `ref` dans un StatefulWidget
- `ref.watch()` = Reconstruit le widget quand l'état change
- `FutureBuilder` = Gère les états async (loading, data, error)

### Pattern 4: Validation et Gestion d'Erreur

**Exemple - Checkout**
```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  
  setState(() {
    _submitting = true;
    _error = null;
  });
  
  try {
    await _repository.placeOrder(
      userId: user.id,
      buyerName: _name.text,
      phone: _phone.text,
      deliveryAddress: _address.text,
      quantities: ref.read(storeCartProvider),
    );
    
    ref.read(storeCartProvider.notifier).clear();
    context.go('/orders/$orderId');
    
  } on StoreException catch (error) {
    setState(() => _error = error.message);
  } finally {
    setState(() => _submitting = false);
  }
}
```

**Bonnes pratiques**:
- Validation avant soumission
- État de chargement (`_submitting`)
- Gestion d'erreurs spécifiques
- Nettoyage avec `finally`

---

## 🎯 QUESTIONS PROBABLES DU PROFESSEUR

### **Niveau 1: Architecture & Concepts**

#### Q1: "Pourquoi avez-vous séparé data/ et ui/ ?"
**Réponse**: 
> J'ai appliqué le principe de **Separation of Concerns**. La couche `data/` gère toute la logique métier et l'accès aux données, tandis que `ui/` se concentre uniquement sur l'affichage. Cela rend le code plus maintenable, testable, et permet de changer la source de données (SQLite → API) sans toucher l'UI.

#### Q2: "Expliquez le rôle du Repository Pattern"
**Réponse**:
> Le **Repository Pattern** abstrait l'accès aux données. Au lieu que chaque page fasse des requêtes SQL directement, elle passe par `StoreRepository`. Cela centralise la logique d'accès aux données, facilite les tests (on peut mocker le repository), et isole l'UI des détails d'implémentation de la base de données.

#### Q3: "Quelle est la différence entre StateNotifier et ChangeNotifier?"
**Réponse**:
> - **StateNotifier** (Riverpod): Immutable, type-safe, avec un seul état typé
> - **ChangeNotifier** (Provider): Mutable, plusieurs propriétés, notifyListeners() manuel
> 
> J'ai choisi StateNotifier car il force l'immutabilité (state = {...state}), ce qui évite les bugs liés aux mutations directes et améliore la traçabilité des changements d'état.

#### Q4: "Comment gérez-vous les rôles utilisateur (User vs Admin)?"
**Réponse**:
> J'utilise `sessionProvider` qui expose l'utilisateur connecté avec son rôle. Dans l'UI:
> ```dart
> final user = ref.watch(sessionProvider);
> if (user?.role == UserRole.admin) {
>   // Afficher interface admin
> }
> ```
> Les opérations sensibles vérifient aussi le rôle côté repository avant d'exécuter la requête SQL.

### **Niveau 2: Fonctionnalités Spécifiques**

#### Q5: "Comment fonctionne le système de panier?"
**Réponse**:
> Le panier est un `StateNotifier<Map<int, int>>` où la clé est l'ID produit et la valeur est la quantité.
> 
> **Flux**:
> 1. User clique "Add to cart" → `ref.read(storeCartProvider.notifier).add(product)`
> 2. Vérification stock disponible
> 3. Mise à jour immutable: `state = {...state, productId: quantity}`
> 4. Tous les widgets qui écoutent (`ref.watch`) se reconstruisent automatiquement
> 
> Le panier persiste en mémoire pendant la session. Au checkout, les données sont envoyées à la base de données.

#### Q6: "Expliquez le workflow de création d'une commande"
**Réponse**:
> **Workflow complet**:
> 1. User ajoute produits au panier (en mémoire)
> 2. Clique "Checkout" → Formulaire de livraison
> 3. Validation des champs (nom, téléphone, adresse)
> 4. `placeOrder()` dans repository:
>    - Vérifie stock disponible pour chaque produit
>    - Crée l'entrée dans `store_orders`
>    - Crée les items dans `store_order_items`
>    - Décrémente le stock des produits
>    - Transaction SQL pour garantir la cohérence
> 5. Vide le panier
> 6. Redirige vers page de confirmation

#### Q7: "Comment un admin change le statut d'une commande?"
**Réponse**:
> Dans `AdminOrdersPage`:
> 1. Admin ouvre la commande (ExpansionTile)
> 2. Voit les boutons selon le statut actuel:
>    - "placed" → "Start processing"
>    - "processing" → "Mark completed"
> 3. Clique le bouton → `_updateStatus(order, newStatus)`
> 4. Repository: `UPDATE store_orders SET status = ?, updated_by = ? WHERE id = ?`
> 5. Page se recharge automatiquement grâce aux `ValueKey` uniques
> 6. La commande se déplace vers la section correspondante

#### Q8: "Comment fonctionne le système de reviews?"
**Réponse**:
> **Composants**:
> - Table `product_reviews` (user_id, product_id, rating, comment)
> - Dialog `AddReviewDialog` pour soumettre
> - Page `ProductReviewsPage` pour afficher
> 
> **Fonctionnalités**:
> - Calcul note moyenne en temps réel avec `AVG(rating)`
> - Distribution des notes (combien de 5★, 4★, etc.)
> - Limitation: 1 review par user par produit (UNIQUE constraint)

### **Niveau 3: Défis Techniques**

#### Q9: "Quel a été le plus gros défi technique?"
**Réponse**:
> Le **support web avec SQLite**. SQLite natif ne fonctionne pas sur web. J'ai dû:
> 1. Ajouter `sqflite_common_ffi_web` pour la compatibilité web
> 2. Gérer les images en base64 (pas de système de fichiers web)
> 3. Implémenter `ImageService` pour encoder/décoder automatiquement
> 4. Tester sur Chrome et Android pour garantir la cohérence

#### Q10: "Comment avez-vous optimisé les performances?"
**Réponse**:
> **Optimisations appliquées**:
> 1. **Queries SQL optimisées** avec indexes sur colonnes fréquemment filtrées
> 2. **Pagination** pour les listes longues (50 items par page)
> 3. **Keys uniques** dans les widgets pour éviter reconstructions inutiles
> 4. **Lazy loading** avec FutureBuilder (données chargées seulement quand nécessaire)
> 5. **Image caching** avec Flutter's default cache

#### Q11: "Gestion des erreurs réseau/base de données?"
**Réponse**:
> J'ai créé `StoreException` personnalisée:
> ```dart
> try {
>   await repository.placeOrder(...);
> } on StoreException catch (error) {
>   // Erreur métier (ex: stock insuffisant)
>   showSnackBar(error.message);
> } catch (error) {
>   // Erreur système inattendue
>   logError(error);
>   showSnackBar('Erreur technique');
> }
> ```
> Chaque repository method lance des exceptions explicites avec messages utilisateur-friendly.

#### Q12: "Comment garantissez-vous la cohérence des données?"
**Réponse**:
> **Mécanismes**:
> 1. **Transactions SQL** pour opérations multiples (ex: création commande + items)
> 2. **Constraints** database (FOREIGN KEY, UNIQUE, CHECK)
> 3. **Validation** côté application avant insertion
> 4. **Vérifications stock** avant ajout au panier et avant checkout
> 5. **État immutable** avec StateNotifier pour éviter mutations accidentelles

### **Niveau 4: Design & UX**

#### Q13: "Pourquoi ce choix de palette de couleurs?"
**Réponse**:
> J'ai choisi une **palette bleu/gris professionnelle**:
> - **Bleu (#2F6BCB, #173B7A)**: Confiance, professionnalisme, calme
> - **Gris (#5A6577, #6B7280)**: Neutralité, élégance, lisibilité
> 
> **Principes appliqués**:
> - Contraste suffisant pour accessibilité (WCAG)
> - Cohérence sur toutes les pages
> - Hiérarchie visuelle claire (primary actions en bleu, secondaires en gris)

#### Q14: "Comment avez-vous rendu l'interface intuitive?"
**Réponse**:
> **Principes UX appliqués**:
> 1. **Feedback immédiat**: SnackBars pour confirmer actions
> 2. **États de chargement**: CircularProgressIndicator pendant requêtes
> 3. **Messages d'erreur clairs**: "Stock insuffisant" au lieu de "Error 500"
> 4. **Navigation cohérente**: Breadcrumbs visuels, back buttons
> 5. **Affordances**: Boutons avec icônes explicites
> 6. **Groupement logique**: Commandes groupées par statut

### **Niveau 5: Évolutions Futures**

#### Q15: "Comment feriez-vous évoluer ce module?"
**Réponse**:
> **Évolutions possibles**:
> 1. **Backend API REST**: Remplacer SQLite par API pour multi-devices sync
> 2. **Paiement en ligne**: Intégration Stripe/PayPal
> 3. **Notifications push**: Alertes sur changements statut commande
> 4. **Analytics**: Tracking comportement utilisateur avec Firebase Analytics
> 5. **Recommendations**: ML pour suggestions produits personnalisées
> 6. **Chat en temps réel**: Firebase/WebSocket pour vendeur-acheteur
> 7. **Multi-langue**: i18n pour support international

#### Q16: "Comment fonctionne le scanner QR/Barcode?" 📱
**Réponse**:
> **Capteur local utilisé**: Caméra du téléphone
> 
> **Package**: `mobile_scanner` v5.2.3 (accès caméra natif)
> 
> **Deux modes de scan**:
> 1. **Mode Produit** (Barcode): Scanner code-barres pour recherche rapide de produits
> 2. **Mode Commande** (QR Code): Scanner QR code pour voir détails commande
> 
> **Workflow Scanner Produit**:
> ```dart
> 1. User clique icône scanner dans StorePage
> 2. QRScannerPage s'ouvre avec caméra
> 3. MobileScannerController détecte code-barres
> 4. parseProductBarcode() extrait le code
> 5. publicProducts(searchTerm: barcode) cherche produit
> 6. Navigation vers ProductDetailsPage
> ```
> 
> **Workflow QR Code Commande**:
> ```dart
> 1. OrderDetailsPage → "Show QR Code"
> 2. QRCodeDisplayPage génère QR avec format "ORDER:{orderId}"
> 3. Admin/Livreur scanne le QR
> 4. orderById() récupère la commande
> 5. Navigation vers OrderDetailsPage
> ```
> 
> **Permissions Android**: CAMERA dans AndroidManifest.xml
> 
> **Formats supportés**: QR Code, EAN13, EAN8, Code128
> 
> **Features**:
> - Overlay personnalisé avec cadre et coins
> - Contrôle torche (flash)
> - Switch caméra avant/arrière
> - Détection temps réel avec feedback visuel

#### Q17: "Comment testeriez-vous ce module?"
**Réponse**:
> **Stratégie de tests**:
> ```dart
> // 1. Unit Tests (Repository)
> test('should add product to cart', () {
>   final cart = StoreCart();
>   final product = StoreProduct(id: 1, stock: 10);
>   expect(cart.add(product), true);
>   expect(cart.state[1], 1);
> });
> 
> // 2. Widget Tests (UI)
> testWidgets('cart page shows products', (tester) async {
>   await tester.pumpWidget(MyApp());
>   expect(find.text('Cart'), findsOneWidget);
> });
> 
> // 3. Integration Tests (E2E)
> testWidgets('complete order flow', (tester) async {
>   // Add to cart → Checkout → Confirm
> });
> ```

---

## 🎓 CONSEILS POUR LA VALIDATION

### Avant la présentation:
1. ✅ **Lancez l'app** et testez chaque feature
2. ✅ **Préparez démo**: Scénario utilisateur complet (browse → add cart → checkout)
3. ✅ **Connaissez les chiffres**: Combien de lignes? Combien de tables? Combien de pages?

### Pendant la présentation:
1. 🎯 **Commencez par l'architecture** (vue d'ensemble avant détails)
2. 💡 **Montrez le code** pendant l'explication (pas juste parler)
3. 🚀 **Démo live**: "Laissez-moi vous montrer..." (plus convaincant)
4. 🤔 **Si vous ne savez pas**: "Je n'ai pas implémenté ça mais voici comment je le ferais..."

### Phrases clés à utiliser:
- "J'ai appliqué le principe de..."
- "Pour garantir la scalabilité..."
- "En termes de performance..."
- "Pour l'expérience utilisateur..."
- "Si je devais améliorer..."

---

## 📊 MÉTRIQUES CLÉS À CONNAÎTRE

- **Lignes de code**: ~4600 lignes ajoutées
- **Fichiers modifiés**: 16 fichiers UI + 6 fichiers data
- **Tables database**: 6 tables (products, orders, order_items, reviews, contact_requests, wishlist)
- **Pages UI**: 17 pages (8 user, 4 admin, 5 communes)
- **Providers**: 2 (storeCartProvider, wishlistProvider)
- **Modèles**: 6 classes principales

---

## 🔥 DÉMONSTRATION RECOMMANDÉE (5-10 min)

### Scénario complet:

**1. En tant que User** (4 min):
```
→ Browse products (filtre par catégorie)
→ 📷 Scanner un code-barres pour recherche rapide
→ Voir détails produit + reviews
→ Ajouter au panier
→ Voir panier (modifier quantités)
→ Checkout (remplir formulaire)
→ Confirmer commande
→ 📷 Afficher QR code de la commande
→ Voir historique commandes
```

**2. En tant que Admin** (3 min):
```
→ Voir toutes les commandes (groupées par statut)
→ 📷 Scanner QR code d'une commande
→ Ouvrir une commande "placed"
→ Changer statut → "processing"
→ Voir statistiques (StoreStatsPage)
→ Gérer produits (approuver/refuser)
```

**3. Vendre un produit** (2 min):
```
→ "Sell Something" (formulaire popup)
→ Attente approbation admin
→ Admin approuve
→ Produit visible dans le store
```

---

## ✅ CHECKLIST FINALE

Avant la validation, vérifiez:
- [ ] L'app compile sans erreurs
- [ ] Toutes les features fonctionnent (testées)
- [ ] 📷 Scanner QR/Barcode fonctionne sur appareil physique (nécessite caméra)
- [ ] La base de données est migrée (version 3)
- [ ] Les branches Git sont mergées
- [ ] Vous pouvez expliquer chaque partie du code
- [ ] Vous avez préparé des réponses aux questions ci-dessus
- [ ] Vous êtes prêt à coder en direct si demandé

---

## 📷 CAPTEUR LOCAL - QR/BARCODE SCANNER

### Implémentation technique:

**Package utilisé**: `mobile_scanner: ^5.2.3`

**Fichiers créés**:
1. `qr_scanner_service.dart` - Service de parsing/génération
2. `qr_scanner_page.dart` - UI du scanner avec caméra
3. `qr_code_display_page.dart` - Affichage QR code commande

**Permissions Android** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" />
```

**Points d'accès**:
- StorePage: Icône scanner dans AppBar (mode produit)
- OrdersPage: Icône scanner dans AppBar (mode commande)
- OrderDetailsPage: Bouton "Show QR Code"

**Formats supportés**:
- QR Code (commandes)
- EAN13, EAN8 (produits)
- Code128 (produits)

**Note importante**: ⚠️ Le scanner nécessite un appareil physique avec caméra. Ne fonctionne pas dans l'émulateur web.

---

**Bonne chance pour votre validation! 🚀**

*N'hésitez pas à revenir sur des points spécifiques si besoin.*
