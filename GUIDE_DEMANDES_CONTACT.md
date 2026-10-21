# 📬 Guide - Système de demandes de contact pour vendeurs

## Vue d'ensemble

Le système permet aux acheteurs de contacter les vendeurs pour les produits communautaires, et aux vendeurs de gérer ces demandes.

---

## 🛍️ Pour l'acheteur

### Comment contacter un vendeur

1. **Aller sur la page Store** (`/store`)
2. **Choisir l'onglet "Community"**
3. **Cliquer sur un produit** pour voir ses détails
4. **Cliquer sur "Contact seller"** (bouton bleu en bas)
5. **Remplir le formulaire**:
   - Votre numéro de téléphone (minimum 6 chiffres)
   - Message optionnel (max 300 caractères)
6. **Envoyer** la demande

### Ce qui se passe après

- La demande est enregistrée dans la base de données
- Le vendeur reçoit votre numéro de téléphone et votre message
- Le vendeur vous contactera directement par téléphone
- Message de confirmation affiché: "Message sent!"

---

## 📞 Pour le vendeur

### Accéder aux demandes de contact

**3 façons d'accéder:**

1. **Depuis la page Store:**
   - Aller sur `/store`
   - Cliquer sur l'icône ✉️ (mail) dans le header
   
2. **URL directe:**
   - Naviguer vers `/store/contact-requests`

3. **Route complète:**
   - `lib/features/store/ui/seller_contact_requests_page.dart`

### Interface de gestion

#### Organisation par statut

Les demandes sont organisées en 3 sections:

1. **🟠 Pending (Nouveau)** - Demandes non traitées
2. **🔵 Contacted (Contacté)** - Vous avez contacté l'acheteur
3. **⚫ Closed (Fermé)** - Demandes terminées

#### Informations affichées pour chaque demande

```
┌─────────────────────────────────────────┐
│ 👤 Nom de l'acheteur                    │
│ ⏰ Date (il y a X heures/jours)         │
│ 📦 Titre du produit                     │
│ 📱 Numéro de téléphone (copiable)      │
│ 💬 Message de l'acheteur (si présent)  │
│ ✅ Actions disponibles                  │
└─────────────────────────────────────────┘
```

#### Actions disponibles

**Pour les demandes "Pending":**
- **Close** → Marquer comme fermé sans contact
- **Mark as contacted** → Indiquer que vous avez contacté l'acheteur

**Pour les demandes "Contacted":**
- **Close request** → Finaliser la demande

**Pour les demandes "Closed":**
- Aucune action (lecture seule)

#### Fonctionnalités utiles

- **📋 Copier le numéro:** Cliquez sur l'icône de copie à côté du numéro
- **🔄 Rafraîchir:** Bouton refresh dans le header
- **📊 Tri automatique:** Les demandes pending apparaissent en premier

---

## 💾 Structure de la base de données

### Table: `contact_requests`

```sql
CREATE TABLE contact_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  buyer_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  buyer_phone TEXT NOT NULL,
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'contacted', 'closed')),
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Index pour les recherches rapides
CREATE INDEX idx_contact_requests_product ON contact_requests(product_id);
CREATE INDEX idx_contact_requests_seller ON contact_requests(product_id, status);
```

### Statuts possibles

- `pending` - Nouvelle demande non traitée
- `contacted` - Vendeur a contacté l'acheteur
- `closed` - Demande terminée/fermée

---

## 🔧 API Repository

### Méthodes disponibles

#### 1. `sendContactRequest`
**Utilisé par:** Acheteur  
**Action:** Créer une nouvelle demande de contact

```dart
await StoreRepository().sendContactRequest(
  productId: 123,
  buyerId: 456,
  buyerPhone: '0612345678',
  message: 'Est-ce que le produit est toujours disponible?',
);
```

**Validations:**
- Numéro de téléphone minimum 6 caractères
- Produit doit être community et approved
- Message optionnel (max 300 caractères)

---

#### 2. `getContactRequestsForSeller`
**Utilisé par:** Vendeur  
**Action:** Récupérer toutes les demandes pour les produits du vendeur

```dart
final requests = await StoreRepository()
  .getContactRequestsForSeller(sellerId: currentUserId);
```

**Retourne:** Liste de `ContactRequest` triée par:
1. Statut (pending > contacted > closed)
2. Date (plus récent d'abord)

**Jointure SQL:**
- Récupère le titre du produit
- Récupère le nom complet de l'acheteur
- Filtre uniquement les produits du vendeur

---

#### 3. `updateContactRequestStatus`
**Utilisé par:** Vendeur  
**Action:** Changer le statut d'une demande

```dart
await StoreRepository().updateContactRequestStatus(
  requestId: 789,
  newStatus: 'contacted',
  sellerId: currentUserId,
);
```

**Sécurité:**
- Vérifie que la demande appartient bien au vendeur
- Empêche la modification des demandes d'autres vendeurs
- Valide le nouveau statut

---

## 🎨 Interface utilisateur

### Composants visuels

#### Cartes de demande (Request Cards)

**Indicateurs de statut:**
- 🟠 **Pending:** Bordure orange épaisse, icône notification
- 🔵 **Contacted:** Bordure bleue standard, icône téléphone
- ⚫ **Closed:** Bordure grise, icône check

**Badges de couleur:**
- Les badges reprennent les couleurs du statut
- Texte en français: "Nouveau", "Contacté", "Fermé"

#### Format des dates

```dart
"Il y a 5m"     // Moins d'une heure
"Il y a 3h"     // Même jour
"Il y a 2j"     // Cette semaine
"21/05/2024"    // Plus ancien
```

---

## 📍 Routes et navigation

### Routes définies

```dart
// Route principale
GET /store/contact-requests → SellerContactRequestsPage

// Fichiers concernés
lib/features/store/routes.dart
lib/features/store/ui/seller_contact_requests_page.dart
```

### Navigation dans l'app

```
Store Page (/store)
  └─ Header → Icon ✉️
      └─ Click
          └─ /store/contact-requests
              └─ SellerContactRequestsPage
```

---

## 🔒 Sécurité et permissions

### Contrôles d'accès

1. **Création de demande (acheteur):**
   - Doit être connecté
   - Produit doit être community + approved
   - Ne peut pas contacter pour ses propres produits

2. **Visualisation des demandes (vendeur):**
   - Doit être connecté
   - Voit uniquement les demandes pour SES produits
   - Requête SQL filtrée par `seller_id`

3. **Mise à jour du statut (vendeur):**
   - Double vérification: demande + propriété du produit
   - Empêche la modification croisée

---

## 📊 Cas d'usage typiques

### Scénario 1: Première vente
```
1. Acheteur voit un vélo d'occasion à 150 TND
2. Clique "Contact seller"
3. Entre son numéro: 0612345678
4. Message: "Le vélo est-il toujours disponible?"
5. Vendeur reçoit la demande (statut: pending)
6. Vendeur appelle l'acheteur
7. Vendeur marque "contacted"
8. Transaction réalisée
9. Vendeur ferme la demande → "closed"
```

### Scénario 2: Demande sans suite
```
1. Acheteur contacte pour un supplément
2. Vendeur voit la demande
3. Vendeur appelle mais pas de réponse
4. Vendeur marque "contacted"
5. Après plusieurs tentatives
6. Vendeur ferme la demande → "closed"
```

### Scénario 3: Produit déjà vendu
```
1. Acheteur contacte pour un produit
2. Vendeur voit que le produit est déjà vendu
3. Vendeur ferme directement (Close)
4. Statut passe à "closed" sans passer par "contacted"
```

---

## 🎯 Améliorations futures possibles

### Court terme
- [ ] Badge avec nombre de demandes pending dans le header
- [ ] Notification push quand nouvelle demande
- [ ] Filtre par produit

### Moyen terme
- [ ] Système de chat in-app
- [ ] Historique des conversations
- [ ] Notes privées sur les demandes

### Long terme
- [ ] Système de notation acheteur/vendeur
- [ ] Intégration SMS automatique
- [ ] Statistiques de conversion

---

## 🐛 Résolution de problèmes

### L'acheteur ne voit pas le bouton "Contact seller"

**Causes possibles:**
- Produit n'est pas community (c'est un produit officiel)
- Produit status ≠ 'approved'
- Acheteur n'est pas connecté

**Solution:** Vérifier que `product.source === 'community'` et `product.status === 'approved'`

---

### Le vendeur ne voit pas ses demandes

**Causes possibles:**
- Vendeur n'est pas connecté
- Aucune demande pour ses produits
- Problème de requête SQL

**Debug:**
```dart
// Vérifier l'ID utilisateur
final userId = ref.read(sessionProvider)?.id;
print('Seller ID: $userId');

// Vérifier les produits du vendeur
SELECT * FROM products WHERE seller_id = userId AND source = 'community';

// Vérifier les demandes
SELECT * FROM contact_requests cr
JOIN products p ON p.id = cr.product_id
WHERE p.seller_id = userId;
```

---

### Erreur lors de la mise à jour du statut

**Message:** "Contact request not found"

**Cause:** Le vendeur tente de modifier une demande qui ne lui appartient pas

**Solution:** Vérifier que:
```sql
SELECT cr.id 
FROM contact_requests cr
JOIN products p ON p.id = cr.product_id
WHERE cr.id = ? AND p.seller_id = ?
```

---

## ✅ Checklist de test

### Tests fonctionnels

- [ ] Acheteur peut créer une demande
- [ ] Demande apparaît chez le vendeur (pending)
- [ ] Vendeur peut copier le numéro de téléphone
- [ ] Vendeur peut marquer "contacted"
- [ ] Vendeur peut fermer une demande
- [ ] Tri par statut fonctionne
- [ ] Dates s'affichent correctement
- [ ] Refresh actualise les données

### Tests de sécurité

- [ ] Acheteur non connecté ne peut pas envoyer
- [ ] Vendeur voit uniquement ses demandes
- [ ] Impossible de modifier les demandes d'autres vendeurs
- [ ] Validation du numéro de téléphone
- [ ] Validation de la longueur du message

---

## 📝 Commit et déploiement

**Commit:** b5d37e7  
**Branch:** Store  
**Fichiers modifiés:** 7  
**Lignes ajoutées:** +572  
**Lignes supprimées:** -8

**Nouveaux fichiers:**
- `lib/features/store/data/contact_request_model.dart`
- `lib/features/store/ui/seller_contact_requests_page.dart`

**Fichiers modifiés:**
- `lib/core/database/schema.dart`
- `lib/core/database/database_helper.dart`
- `lib/features/store/data/store_repository.dart`
- `lib/features/store/routes.dart`
- `lib/features/store/ui/store_page.dart`

---

## 🎉 Résumé

Le système de demandes de contact est maintenant **complet et fonctionnel**:

✅ Les acheteurs peuvent contacter les vendeurs  
✅ Les demandes sont stockées en base de données  
✅ Les vendeurs ont une interface dédiée pour gérer les demandes  
✅ 3 statuts pour suivre l'avancement  
✅ Interface intuitive avec codes couleur  
✅ Sécurité et permissions implémentées  
✅ Prêt pour la production

**Route vendeur:** `/store/contact-requests`

Tous les changements ont été committés et pushés sur la branche Store! 🚀
