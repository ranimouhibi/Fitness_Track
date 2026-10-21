# 🔄 Instructions pour migrer la base de données

## Problème

Les erreurs suivantes apparaissent:
- `no such table: wishlist`
- `no such table: contact_requests`
- `no such table: product_reviews`

## Cause

La base de données existante a été créée avec la version 2, mais les nouvelles tables (wishlist, product_reviews, contact_requests) ont été ajoutées après. La migration automatique créera ces tables.

## ✅ Solution

### Option 1: Supprimer la base de données web (RECOMMANDÉ pour le développement)

**Sur Chrome:**

1. **Ouvrir les DevTools**
   - Appuyer sur `F12` ou `Ctrl+Shift+I`

2. **Aller dans l'onglet "Application"**
   - Si vous ne voyez pas cet onglet, cliquez sur les `>>` à droite

3. **Dans le menu de gauche:**
   - Cliquer sur "Storage" → "IndexedDB"
   - Vous verrez `sqflite_databases`

4. **Supprimer la base de données:**
   - Clic droit sur `sqflite_databases`
   - Choisir "Delete database"
   - OU: Clic droit sur `fittrack.db` → "Delete"

5. **Rafraîchir la page**
   - `F5` ou `Ctrl+R`
   - La base de données sera recréée avec la version 3

**Alternative via Console:**

1. Ouvrir DevTools → Console
2. Exécuter:
```javascript
indexedDB.deleteDatabase('sqflite_databases');
location.reload();
```

### Option 2: Attendre la migration automatique

La migration devrait se déclencher automatiquement si:
- Vous fermez complètement Chrome
- Vous rouvrez l'application
- La version détectée (2) < nouvelle version (3)

**MAIS**: Si cela ne fonctionne pas, utilisez l'Option 1.

---

## ⚠️ Important

### Données de test perdues

En supprimant la base de données:
- ❌ Tous les produits ajoutés seront perdus
- ❌ Toutes les commandes seront perdues
- ❌ Toutes les annonces seront perdues
- ✅ Les comptes de test seront recréés automatiquement:
  - admin@fittrack.com / Admin123!
  - coach@fittrack.com / Coach123!
  - user@fittrack.com / User123!

### En production

Pour une application en production, les données utilisateurs seraient préservées car:
1. La migration automatique fonctionne correctement
2. Les utilisateurs n'ont pas besoin de supprimer manuellement
3. SQLite applique automatiquement le `onUpgrade`

---

## 🧪 Vérification après suppression

1. **Rafraîchir la page** (`F5`)

2. **Se connecter** avec un compte test:
   - Email: `user@fittrack.com`
   - Mot de passe: `User123!`

3. **Tester les fonctionnalités:**
   - ✅ Aller sur Store → Ajouter un produit à la wishlist
   - ✅ Voir un produit → Laisser un avis (review)
   - ✅ Produit community → Contacter le vendeur

4. **Vérifier les tables dans DevTools:**
   - Application → IndexedDB → sqflite_databases → fittrack.db
   - Vous devriez voir:
     - `wishlist` (table)
     - `product_reviews` (table)
     - `contact_requests` (table)

---

## 📋 Checklist de test complet

Après la migration, testez:

- [ ] Wishlist
  - [ ] Ajouter un produit à la wishlist
  - [ ] Voir la wishlist page
  - [ ] Retirer un produit de la wishlist

- [ ] Reviews
  - [ ] Laisser un avis sur un produit
  - [ ] Voir les avis d'un produit
  - [ ] Voir le rating moyen

- [ ] Contact requests
  - [ ] Envoyer une demande de contact (acheteur)
  - [ ] Voir les demandes (vendeur)
  - [ ] Marquer comme "contacted"
  - [ ] Fermer une demande

---

## 🔍 Debug

### Si les erreurs persistent après suppression

1. **Vérifier la version de la DB:**
```sql
-- Dans DevTools → Application → IndexedDB
-- Ouvrir fittrack.db
-- Chercher la table "pragma" ou "user_version"
-- La version doit être 3
```

2. **Vérifier que les tables existent:**
```sql
SELECT name FROM sqlite_master WHERE type='table';
```

Vous devez voir:
- users
- products
- store_orders
- store_order_items
- **wishlist** ✅
- **product_reviews** ✅
- **contact_requests** ✅
- ... (autres tables)

3. **Vider le cache du navigateur:**
   - Chrome → Paramètres → Confidentialité et sécurité
   - Effacer les données de navigation
   - Cocher "Images et fichiers en cache"
   - Ne PAS cocher "Cookies et autres données"

4. **Hard refresh:**
   - `Ctrl+Shift+R` (Windows/Linux)
   - `Cmd+Shift+R` (Mac)

---

## 💡 Pour éviter ce problème à l'avenir

### Lors de l'ajout de nouvelles tables:

1. **Incrémenter la version:**
```dart
static const _dbVersion = 4; // Prochaine version
```

2. **Ajouter dans onCreate:**
```dart
onCreate: (db, version) async {
  // ... tables existantes
  for (final statement in newTableStatements) {
    await db.execute(statement);
  }
}
```

3. **Ajouter dans onUpgrade:**
```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 4) {
    for (final statement in newTableStatements) {
      await db.execute(statement);
    }
  }
}
```

4. **Tester sur une nouvelle installation ET une mise à jour:**
   - Nouvelle installation → onCreate
   - Mise à jour → onUpgrade

---

## ✅ Résumé rapide

**Pour développeur:**
1. Ouvrir DevTools (F12)
2. Application → IndexedDB → sqflite_databases
3. Delete database
4. Rafraîchir (F5)
5. Tester les nouvelles fonctionnalités

**Temps estimé:** 30 secondes

Tout devrait fonctionner après! 🚀
