import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'item_detail_page.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'product_icons.dart';
import 'cart_icon_badge.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String searchQuery = '';
  
  // Cache for business availability status
  Map<String, bool> _businessAvailability = {};

  Future<bool> _isBusinessAcceptingOrders(String businessId) async {
    // Return cached value if available
    if (_businessAvailability.containsKey(businessId)) {
      return _businessAvailability[businessId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final accepting = data['acceptingReservations'] ?? true;
        _businessAvailability[businessId] = accepting;
        return accepting;
      }
    } catch (e) {
      // Handle error
    }

    _businessAvailability[businessId] = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Get screen width for responsive grid
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 3;
    if (screenWidth > 600) crossAxisCount = 3;
    if (screenWidth > 900) crossAxisCount = 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search items...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('products')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final products = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['productId'] = doc.id;
                    return data;
                  }).toList();

                  final filtered = products.where((item) {
                    final name = (item['name'] ?? '').toString().toLowerCase();
                    final category = (item['category'] ?? '').toString().toLowerCase();

                    return name.contains(searchQuery.toLowerCase()) ||
                        category.contains(searchQuery.toLowerCase());
                  }).toList();

                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _categorizeProducts(filtered),
                    builder: (context, categorizedSnapshot) {
                      if (!categorizedSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final categorized = categorizedSnapshot.data!;
                      final available = categorized.where((p) => p['_isAvailable'] == true).toList();
                      final unavailable = categorized.where((p) => p['_isAvailable'] == false).toList();

                      return CustomScrollView(
                        slivers: [
                          // Available items grid
                          if (available.isNotEmpty) ...[
                            SliverPadding(
                              padding: const EdgeInsets.only(bottom: 8),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  '${available.length} items available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProductCard(available[index], isAvailable: true),
                                childCount: available.length,
                              ),
                            ),
                          ],

                          // Unavailable items section
                          if (unavailable.isNotEmpty) ...[
                            SliverPadding(
                              padding: const EdgeInsets.only(top: 24, bottom: 12),
                              sliver: SliverToBoxAdapter(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.pause_circle_outline, 
                                        size: 20, 
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Unavailable (${unavailable.length})',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Seller not accepting orders',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 0.75,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildProductCard(unavailable[index], isAvailable: false),
                                childCount: unavailable.length,
                              ),
                            ),
                          ],

                          // Empty state
                          if (available.isEmpty && unavailable.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No products found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _categorizeProducts(List<Map<String, dynamic>> products) async {
    final List<Map<String, dynamic>> result = [];

    for (final product in products) {
      final businessId = product['businessId'] ?? '';
      final isAvailable = await _isBusinessAcceptingOrders(businessId);
      result.add({...product, '_isAvailable': isAvailable});
    }

    return result;
  }

  Widget _buildProductCard(Map<String, dynamic> item, {required bool isAvailable}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ItemDetailPage(item: item),
          ),
        );
      },
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: Card(
          elevation: isAvailable ? 2 : 1,
          color: isAvailable ? Colors.white : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isAvailable 
                ? BorderSide.none 
                : BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isAvailable 
                              ? Colors.green.shade100 
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Icon(
                            ProductIcons.fromKey(item['iconKey']),
                            size: 50,
                            color: isAvailable ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                      // Unavailable badge
                      if (!isAvailable)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, 
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade600,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'UNAVAILABLE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  item['name'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? Colors.black : Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Text(
                  '\$${(item['price'] ?? 0).toString()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isAvailable ? Colors.green.shade700 : Colors.grey,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  item['category'] ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}