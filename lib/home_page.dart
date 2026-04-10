import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'shop_page.dart';
import 'item_detail_page.dart';
import 'business_detail_page.dart';
import 'app_bottom_nav.dart';
import 'cart_icon_badge.dart';
import 'services/firestore_service.dart';

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
  double? userLat;
  double? userLng;

  // Helper to get all aliases for a category (lowercase)
  List<String> _getAliasesForCategory(String categoryName) {
    final aliases = categoryAliases[categoryName] ?? [];
    // Include the category name itself
    return [categoryName.toLowerCase(), ...aliases];
  }

  List<Map<String, dynamic>> featuredSellers = [];

    @override
    void initState() {
      super.initState();
      _loadFeaturedSellers();
      _loadUserLocation();
    }

    Future<void> _loadUserLocation() async {
      // For Atlanta dummy data:
      userLat = 33.7490;  // Atlanta lat
      userLng = -84.3880; // Atlanta lng
      
      // Or save to Firestore for persistence
      await _firestoreService.updateUserLocation(
        latitude: 33.7490,
        longitude: -84.3880,
        city: 'Atlanta',
      );
      
      // Load nearby sellers
      final nearby = await _firestoreService.getNearbyBusinesses(
        userLat: userLat!,
        userLng: userLng!,
        limit: 6,
      );
      
      setState(() => nearbySellers = nearby);
    }

    Future<void> _loadFeaturedSellers() async {
    // Fetch more businesses than we need
    final snapshot = await FirebaseFirestore.instance
        .collection('businesses')
        .limit(20)  // Get more so we have variety
        .get();

    final allSellers = snapshot.docs.map((doc) {
      final data = doc.data();
      data['businessId'] = doc.id;
      return data;
    }).toList();

    // Shuffle randomly
    allSellers.shuffle();

    setState(() {
      // Take first 6 after shuffling
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
      body: Padding(
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
              height: 150,
              child: Center(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        width: 120,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            category["icon"]!,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            category["name"]!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Featured Sellers Section
            const Text(
              'Featured Sellers',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: featuredSellers.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : PageView.builder(
                      itemCount: featuredSellers.length,
                      controller: PageController(viewportFraction: 0.8),
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
                            margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                  size: 50,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    seller["name"] ?? "Unknown",
                                    style: const TextStyle(
                                      fontSize: 16,
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
                                        fontSize: 12,
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
          ],
        ),
      ),
      //bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }
}

class CategoryProductsPage extends StatelessWidget {
  final String categoryName;

  const CategoryProductsPage({super.key, required this.categoryName});

  // Category aliases - maps variations to the display category
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
    // Include the category name itself (both original case and lowercase)
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
        stream: FirebaseFirestore.instance
            .collection('products')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final aliases = _getAliasesForCategory();

          // Filter products where category matches any alias
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final productCategory = (data['category'] ?? '').toString().toLowerCase();
            
            // Check if product category matches any alias
            return aliases.any((alias) => 
              productCategory.contains(alias.toLowerCase()) ||
              alias.toLowerCase().contains(productCategory)
            );
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
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.75,
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