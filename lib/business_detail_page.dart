import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';

class BusinessDetailPage extends StatefulWidget {
  final Map<String, dynamic> seller;

  const BusinessDetailPage({super.key, required this.seller});

  @override
  State<BusinessDetailPage> createState() => _BusinessDetailPageState();
}

class _BusinessDetailPageState extends State<BusinessDetailPage> {
  final FirestoreService _firestoreService = FirestoreService();

  String get sellerId => widget.seller['businessId'] ?? '';
  String searchQuery = '';

  Set<String> favoriteSellerIds = {};

  @override
    void initState() {
      super.initState();

      _firestoreService.getFavoriteSellersStream().listen((sellers) {
        setState(() {
          favoriteSellerIds = sellers
              .map((s) => s['businessId'] as String)
              .toSet();
        });
      });
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // HEADER
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search for an item',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // CONTENT
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BUSINESS HEADER
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.seller['name'] ?? 'Unnamed Business',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        IconButton(
                          icon: Icon(
                            favoriteSellerIds.contains(widget.seller['businessId'])
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          color: Colors.red,
                          onPressed: () {
                            final businessId = widget.seller['businessId'] ?? '';
                            if (businessId.isNotEmpty) {
                              _firestoreService.toggleFavoriteSeller(businessId);
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),

                    const Text(
                      'Available Items',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildItemsStream(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STREAM OF PRODUCTS
  Widget _buildItemsStream() {
    final String businessId = widget.seller['businessId'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              "No products available",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final item = doc.data() as Map<String, dynamic>;
            item['productId'] = doc.id;

            return _buildItemCard(item);
          }).toList(),
        );
      },
    );
  }

  // ITEM CARD
  Widget _buildItemCard(Map<String, dynamic> item) {
    final String name = item['name'] ?? 'Unnamed item';
    final String description = item['description'] ?? '';
    final String unit = item['unit'] ?? '';
    final double price = (item['price'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _showItemDetails(item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "\$${price.toStringAsFixed(2)} / $unit",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              color: Theme.of(context).primaryColor,
              onPressed: () {
                _firestoreService.addToCart(item);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item['name']} added to cart!'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ITEM DETAILS BOTTOM SHEET
  void _showItemDetails(Map<String, dynamic> item) {
    final String name = item['name'] ?? '';
    final String description = item['description'] ?? '';
    final String unit = item['unit'] ?? '';
    final double price = (item['price'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "\$${price.toStringAsFixed(2)} / $unit",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _firestoreService.addToCart(item);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item['name']} added to cart!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to Cart'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}