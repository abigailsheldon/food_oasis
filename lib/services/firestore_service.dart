import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // ==================== CART ====================

  /// Add item to cart (basic, no pickup time)
  Future<void> addToCart(Map<String, dynamic> item) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .add({
      'productId': item['productId'] ?? item['id'] ?? '',
      'businessId': item['businessId'] ?? '',
      'name': item['name'] ?? '',
      'price': item['price'] ?? 0,
      'unit': item['unit'] ?? 'ea',
      'quantity': 1,
      'iconKey': item['iconKey'] ?? 'default',
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add item to cart with pickup time
  Future<void> addToCartWithPickupTime(
    Map<String, dynamic> item,
    DateTime pickupTime,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart')
        .add({
      'productId': item['productId'] ?? item['id'] ?? '',
      'businessId': item['businessId'] ?? '',
      'name': item['name'] ?? '',
      'price': item['price'] ?? 0,
      'unit': item['unit'] ?? 'ea',
      'quantity': 1,
      'iconKey': item['iconKey'] ?? 'default',
      'pickupTime': Timestamp.fromDate(pickupTime),
      'addedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get cart as a stream
  Stream<List<Map<String, dynamic>>> getCartStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
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

  /// Clear entire cart
  Future<void> clearCart() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final cartRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('cart');

    final snapshot = await cartRef.get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ==================== FAVORITES ====================

  /// Toggle favorite seller
  Future<void> toggleFavoriteSeller(String businessId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(businessId);

    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
    } else {
      await docRef.set({
        'businessId': businessId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get favorite sellers as stream
  Stream<List<Map<String, dynamic>>> getFavoriteSellersStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .asyncMap((snapshot) async {
      final favorites = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final businessId = doc.id;
        final businessDoc = await _firestore
            .collection('businesses')
            .doc(businessId)
            .get();

        if (businessDoc.exists) {
          final data = businessDoc.data()!;
          data['businessId'] = businessId;
          favorites.add(data);
        }
      }

      return favorites;
    });
  }

  // ==================== PRODUCTS ====================

  /// Get products for a business
  Stream<QuerySnapshot> getProducts({required String? businessId}) {
    if (businessId == null || businessId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('products')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Add a new product
  Future<void> addProduct({
    required String businessId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String unit,
    required String category,
    String iconKey = 'default',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('products').add({
      'businessId': businessId,
      'ownerUid': user.uid,
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'iconKey': iconKey,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update an existing product
  Future<void> updateProduct({
    required String productId,
    required String name,
    required String description,
    required double price,
    required int quantity,
    required String unit,
    required String category,
    String iconKey = 'default',
  }) async {
    await _firestore.collection('products').doc(productId).update({
      'name': name,
      'description': description,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'iconKey': iconKey,
    });
  }

  // ==================== BUSINESS PROFILE ====================

  /// Create or update business profile
  Future<void> createOrUpdateBusinessProfile({
    required String? businessId,
    required String name,
    required String address,
    required String description,
    required Map<String, dynamic> hours,
    required bool acceptingReservations,
    double? latitude,
    double? longitude,
  }) async {
    final user = _auth.currentUser;
    if (user == null || businessId == null) return;

    await _firestore.collection('businesses').doc(businessId).set({
      'name': name,
      'address': address,
      'description': description,
      'hours': hours,
      'acceptingReservations': acceptingReservations,
      'ownerUid': user.uid,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== ORDERS ====================

  /// Create an order from cart items
  Future<void> createOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String deliveryAddress,
    String? notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Group items by business for separate pickups
    final itemsByBusiness = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final businessId = item['businessId'] ?? 'unknown';
      itemsByBusiness.putIfAbsent(businessId, () => []).add(item);
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('orders')
        .add({
      'items': items,
      'itemsByBusiness': itemsByBusiness,
      'total': total,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Clear the cart after order
    await clearCart();
  }

  // ==================== REVIEWS ====================

  /// Add a review for a business
  Future<void> addReview({
    required String businessId,
    required int rating,
    required String comment,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Get user name
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['name'] ?? 'Anonymous';

    await _firestore.collection('reviews').add({
      'businessId': businessId,
      'reviewerId': user.uid,
      'reviewerName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get reviews for a business
  Stream<QuerySnapshot> getReviewsForBusiness(String businessId) {
    return _firestore
        .collection('reviews')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ==================== USER LOCATION ====================

  /// Update user's location
  Future<void> updateUserLocation({
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'latitude': latitude,
      'longitude': longitude,
      if (city != null) 'city': city,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user's saved location
  Future<Map<String, dynamic>?> getUserLocation() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();

    if (data != null && data['latitude'] != null && data['longitude'] != null) {
      return {
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'city': data['city'],
      };
    }

    return null;
  }

  // ==================== NEARBY BUSINESSES ====================

  /// Get businesses sorted by distance from a location
  Future<List<Map<String, dynamic>>> getNearbyBusinesses({
    required double userLat,
    required double userLng,
    int limit = 10,
  }) async {
    // Get all businesses with coordinates
    final snapshot = await _firestore
        .collection('businesses')
        .where('latitude', isNotEqualTo: null)
        .limit(50)  // Get more to sort by distance
        .get();

    final businesses = snapshot.docs.map((doc) {
      final data = doc.data();
      data['businessId'] = doc.id;
      
      // Calculate distance (simplified Haversine)
      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;
      
      if (lat != null && lng != null) {
        data['distance'] = _calculateDistance(userLat, userLng, lat, lng);
      } else {
        data['distance'] = double.infinity;
      }
      
      return data;
    }).toList();

    // Sort by distance
    businesses.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double));

    return businesses.take(limit).toList();
  }

  /// Calculate distance in miles between two coordinates
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 3959; // miles
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = 
        (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2));
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
}