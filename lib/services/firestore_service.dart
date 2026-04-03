import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user UID
  String? get uid => _auth.currentUser?.uid;

  // product functions
  Future<void> addProduct({
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String unit,
    required String category,
    required String businessId,
  }) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    await _firestore.collection('products').add({
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'category': category,

      'businessId': businessId,
      'ownerUid': uid,

      'imageUrl': '',
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String productId) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    await _firestore
        .collection('products')
        .doc(productId)
        .delete();
  }

  Future<void> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String unit,
    required String category,
  }) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    await _firestore.collection('products').doc(productId).update({
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getProducts({String? businessId}) {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    Query query = _firestore.collection('products');

    if (businessId != null) {
      query = query.where('businessId', isEqualTo: businessId);
    } else {
      query = query.where('businessId', isEqualTo: '__none__');
    }

    return query.snapshots();
  }

  // business page functions
  Future<String> createOrUpdateBusinessProfile({
    String? businessId,
    required String name,
    required String address,
    required String description,
    required Map<String, dynamic> hours,
    required bool acceptingReservations,
  }) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    final docRef = businessId == null
        ? _firestore.collection('businesses').doc()
        : _firestore.collection('businesses').doc(businessId);

    final id = docRef.id;

    await docRef.set({
      'ownerUid': uid,
      'name': name,
      'address': address,
      'description': description,
      'hours': hours,
      'acceptingReservations': acceptingReservations,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _firestore.collection('users').doc(uid).set({
      'businessId': id,
      'role': 'seller',
    }, SetOptions(merge: true));

    return id;
  }

  // favorites functions
  Stream<List<Map<String, dynamic>>> getFavoriteSellersStream() {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .snapshots()
        .asyncMap((favSnapshot) async {
          final ids = favSnapshot.docs.map((d) => d.id).toList();

          if (ids.isEmpty) return [];

          final businessesSnap = await _firestore
              .collection('businesses')
              .where(FieldPath.documentId, whereIn: ids)
              .get();

          return businessesSnap.docs.map((doc) {
            final data = doc.data();
            data['businessId'] = doc.id;
            return data;
          }).toList();
        });
  }

  Future<void> toggleFavoriteSeller(String sellerId) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    final favRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('favorites')
        .doc(sellerId);

    final doc = await favRef.get();

    if (doc.exists) {
      await favRef.delete();
    } else {
      await favRef.set({
        'businessId': sellerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // cart functions
  Future<void> addToCart(Map<String, dynamic> item) async {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    final cartRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('cart');

    final existing = await cartRef
        .where('productId', isEqualTo: item['productId'])
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;
      await doc.reference.update({
        'quantity': FieldValue.increment(1),
      });
    } else {
      await cartRef.add({
        'productId': item['productId'],
        'businessId': item['businessId'],
        'name': item['name'],
        'price': item['price'],
        'unit': item['unit'],
        'quantity': 1,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  Stream<List<Map<String, dynamic>>> getCartStream() {
    if (uid == null) {
      throw Exception("User not authenticated");
    }

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('cart')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['cartItemId'] = doc.id;
            return data;
          }).toList();
        });
  }

}