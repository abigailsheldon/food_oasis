import 'package:flutter/material.dart';
import 'business_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';
import 'cart_page.dart';
import 'app_bottom_nav.dart';

class ItemDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final FirestoreService firestoreService = FirestoreService();

  String sellerName = '';
  bool isLoadingSeller = true;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    final businessId = widget.item['businessId'] ?? '';

    if (businessId.isEmpty) {
      setState(() {
        sellerName = 'Unknown seller';
        isLoadingSeller = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (!doc.exists) {
        setState(() {
          sellerName = 'Unknown seller';
          isLoadingSeller = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        sellerName = data['name'] ?? 'Unnamed seller';
        isLoadingSeller = false;
      });
    } catch (e) {
      setState(() {
        sellerName = 'Unknown seller';
        isLoadingSeller = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.item['name'] ?? '';
    final String description = widget.item['description'] ?? '';
    final String businessId = widget.item['businessId'] ?? '';
    final double price = (widget.item['price'] ?? 0).toDouble();
    final String category = widget.item['category'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartPage()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER IMAGE
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.green.shade100,
              child: Icon(
                Icons.fastfood,
                size: 100,
                color: Colors.green.shade700,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NAME
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // SELLER NAME (FIXED)
                  Row(
                    children: [
                      const Icon(Icons.storefront,
                          size: 18, color: Colors.grey),
                      const SizedBox(width: 6),

                      isLoadingSeller
                          ? const Text(
                              'Loading seller...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            )
                          : Text(
                              sellerName.isNotEmpty
                                  ? sellerName
                                  : 'Unknown seller',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // PRICE
                  Text(
                    '\$${price.toStringAsFixed(2)} / ${widget.item['unit'] ?? ''}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // DESCRIPTION
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    description.isNotEmpty
                        ? description
                        : 'No description available.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ADD TO CART
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        firestoreService.addToCart(widget.item);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name added to cart!'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // VIEW SELLER
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () async {
                        if (businessId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Business not found'),
                            ),
                          );
                          return;
                        }

                        final doc = await FirebaseFirestore.instance
                            .collection('businesses')
                            .doc(businessId)
                            .get();

                        if (!doc.exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Business no longer exists'),
                            ),
                          );
                          return;
                        }

                        final sellerData = doc.data()!;
                        sellerData['businessId'] = doc.id;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessDetailPage(
                              seller: sellerData,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'View Seller',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}