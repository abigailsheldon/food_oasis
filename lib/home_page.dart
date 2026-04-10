import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'shop_page.dart';
import 'item_detail_page.dart';
import 'business_detail_page.dart';
import 'app_bottom_nav.dart';
import 'cart_icon_badge.dart';
import 'services/firestore_service.dart';
import 'dart:math' as math;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirestoreService _firestoreService = FirestoreService();

  final List<Map<String, String>> categories = const [
    {"name": "Vegan", "icon": "🥗"},
    {"name": "Baked Goods", "icon": "🥐"},
    {"name": "Fruits", "icon": "🍎"},
    {"name": "Vegetables", "icon": "🥕"},
    {"name": "Dairy", "icon": "🥛"},
    {"name": "Drinks", "icon": "🧃"},
  ];

  // Category aliases - maps variations to the display category
  static const Map<String, List<String>> categoryAliases = {
    "Vegan": ["vegan", "plant-based", "plant based", "vegetarian"],
    "Baked Goods": ["baked goods", "baked", "bakery", "pastry", "pastries", "bread", "breads"],
    "Fruits": ["fruits", "fruit", "apple", "apples", "orange", "oranges", "berry", "berries"],
    "Vegetables": ["vegetables", "vegetable", "veggie", "veggies", "produce", "veg"],
    "Dairy": ["dairy", "milk", "cheese", "yogurt", "eggs", "egg", "butter"],
    "Drinks": ["drinks", "drink", "beverage", "beverages", "juice", "juices", "smoothie", "smoothies"],
  };

  List<Map<String, dynamic>> nearbySellers = [];
  List<Map<String, dynamic>> featuredSellers = [];
  double? userLat;
  double? userLng;
  String? userCity;
  bool isLoadingLocation = true;
  bool locationDenied = false;

  // Helper to get all aliases for a category (lowercase)
  List<String> _getAliasesForCategory(String categoryName) {
    final aliases = categoryAliases[categoryName] ?? [];
    return [categoryName.toLowerCase(), ...aliases];
  }

  @override
  void initState() {
    super.initState();
    _loadFeaturedSellers();
    _loadUserLocation();
  }

  /// Get user's actual device location using Geolocator
  Future<void> _loadUserLocation() async {
    setState(() => isLoadingLocation = true);

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Fall back to Atlanta
        _useAtlantaLocation();
        return;
      }

      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useAtlantaLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _useAtlantaLocation();
        return;
      }

      // Get actual position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      userLat = position.latitude;
      userLng = position.longitude;
      userCity = 'Current Location';
      locationDenied = false;

      // Save to Firestore
      await _firestoreService.updateUserLocation(
        latitude: userLat!,
        longitude: userLng!,
        city: 'Current Location',
      );

      // Load nearby sellers
      await _loadNearbySellers();

    } catch (e) {
      debugPrint('Error getting location: $e');
      _useAtlantaLocation();
    }

    setState(() => isLoadingLocation = false);
  }

  /// Fall back to Atlanta coordinates
  void _useAtlantaLocation() {
    userLat = 33.7490;
    userLng = -84.3880;
    userCity = 'Atlanta, GA';
    locationDenied = true;
    _loadNearbySellers();
    setState(() => isLoadingLocation = false);
  }

  /// Load nearby sellers based on user location
  Future<void> _loadNearbySellers() async {
    if (userLat == null || userLng == null) return;

    // Get all businesses and calculate distance
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .limit(50)
        .get();

    final List<Map<String, dynamic>> businessesWithDistance = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      data['businessId'] = doc.id;

      // Get business coordinates
      final lat = data['latitude'] as double?;
      final lng = data['longitude'] as double?;

      if (lat != null && lng != null) {
        // Calculate distance in miles
        final distance = _calculateDistance(userLat!, userLng!, lat, lng);
        data['distance'] = distance;
        businessesWithDistance.add(data);
      } else {
        // Businesses without coordinates - assign a random "nearby" distance for demo
        // In production, you'd skip these or geocode their addresses
        data['distance'] = 5.0 + (doc.id.hashCode % 20); // Random 5-25 miles
        businessesWithDistance.add(data);
      }
    }

    // Sort by distance
    businessesWithDistance.sort((a, b) =>
        (a['distance'] as double).compareTo(b['distance'] as double));

    setState(() {
      nearbySellers = businessesWithDistance.take(6).toList();
    });
  }

  /// Calculate distance in miles using Haversine formula
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 3959; // miles

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2));

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

  Future<void> _loadFeaturedSellers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .limit(20)
        .get();

    final allSellers = snapshot.docs.map((doc) {
      final data = doc.data();
      data['businessId'] = doc.id;
      return data;
    }).toList();

    allSellers.shuffle();

    setState(() {
      featuredSellers = allSellers.take(6).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FavoritesPage()),
            ),
          ),
          const CartIconBadge(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categories Section
            const Text(
              'Categories',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryProductsPage(
                            categoryName: category["name"]!,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category["icon"]!,
                            style: const TextStyle(fontSize: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category["name"]!,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ============ NEARBY SELLERS SECTION ============
            Row(
              children: [
                Icon(Icons.near_me, size: 22, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Nearby Sellers',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isLoadingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: _loadUserLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            userCity ?? 'Atlanta',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (isLoadingLocation)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (nearbySellers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.location_off, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'No nearby sellers found',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: nearbySellers.length,
                  itemBuilder: (context, index) {
                    final seller = nearbySellers[index];
                    final distance = seller['distance'] as double?;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessDetailPage(seller: seller),
                          ),
                        );
                      },
                      child: Container(
                        width: 140,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storefront,
                              size: 40,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                seller['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (distance != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${distance.toStringAsFixed(1)} mi',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24),

            // ============ FEATURED SELLERS SECTION ============
            const Text(
              'Featured Sellers',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 160,
              child: featuredSellers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      itemCount: featuredSellers.length,
                      controller: PageController(viewportFraction: 0.85),
                      itemBuilder: (context, index) {
                        final seller = featuredSellers[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BusinessDetailPage(seller: seller),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.storefront,
                                  size: 44,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    seller["name"] ?? "Unknown",
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (seller["directory"] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      seller["directory"],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============ CATEGORY PRODUCTS PAGE ============
class CategoryProductsPage extends StatelessWidget {
  final String categoryName;

  const CategoryProductsPage({super.key, required this.categoryName});

  static const Map<String, List<String>> categoryAliases = {
    "Vegan": ["vegan", "plant-based", "plant based", "vegetarian"],
    "Baked Goods": ["baked goods", "baked", "bakery", "pastry", "pastries", "bread", "breads"],
    "Fruits": ["fruits", "fruit", "apple", "apples", "orange", "oranges", "berry", "berries"],
    "Vegetables": ["vegetables", "vegetable", "veggie", "veggies", "produce"],
    "Dairy": ["dairy", "milk", "cheese", "yogurt", "eggs", "egg"],
    "Drinks": ["drinks", "drink", "beverage", "beverages", "juice", "juices", "smoothie", "smoothies"],
  };

  List<String> _getAliasesForCategory() {
    final aliases = categoryAliases[categoryName] ?? [];
    return [categoryName, categoryName.toLowerCase(), ...aliases];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        backgroundColor: Colors.green.shade50,
        actions: const [
          CartIconBadge(),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final aliases = _getAliasesForCategory();

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final productCategory = (data['category'] ?? '').toString().toLowerCase();

            return aliases.any((alias) =>
                productCategory.contains(alias.toLowerCase()) ||
                alias.toLowerCase().contains(productCategory));
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No products in "$categoryName"',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              data['productId'] = docs[index].id;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItemDetailPage(item: data),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fastfood,
                              size: 50,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${(data['price'] ?? 0).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }
}