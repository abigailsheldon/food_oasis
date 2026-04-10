import 'package:flutter/material.dart';
import 'business_detail_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';
import 'cart_page.dart';
import 'app_bottom_nav.dart';
import 'product_icons.dart';
import 'pickup_time_selector.dart';

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
  bool acceptingOrders = true;

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
        acceptingOrders = false;
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
          acceptingOrders = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      setState(() {
        sellerName = data['name'] ?? 'Unnamed seller';
        acceptingOrders = data['acceptingReservations'] ?? true;
        isLoadingSeller = false;
      });
    } catch (e) {
      setState(() {
        sellerName = 'Unknown seller';
        isLoadingSeller = false;
        acceptingOrders = false;
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
          _buildCartIconWithBadge(),
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
                ProductIcons.fromKey(widget.item['iconKey']),
                size: 75,
                color: Colors.green,
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

                  // NOT ACCEPTING ORDERS BANNER
                  if (!acceptingOrders && !isLoadingSeller)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This seller is not currently accepting orders.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ADD TO CART
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (!acceptingOrders || isLoadingSeller)
                          ? null
                          : () async {
                              // Show pickup time selector
                              final pickupTime = await PickupTimeSelector.show(
                                context: context,
                                businessId: businessId,
                              );

                              if (pickupTime != null) {
                                // Add to cart with pickup time
                                await firestoreService.addToCartWithPickupTime(
                                  widget.item,
                                  pickupTime,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('$name added to cart!'),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: acceptingOrders ? Colors.green : Colors.grey.shade400,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        acceptingOrders ? 'Add to Cart' : 'Not Available',
                        style: const TextStyle(
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

  Widget _buildCartIconWithBadge() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return IconButton(
        icon: const Icon(Icons.shopping_cart_outlined),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CartPage()),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .snapshots(),
      builder: (context, snapshot) {
        int itemCount = 0;
        if (snapshot.hasData) {
          itemCount = snapshot.data!.docs.length;
        }

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (itemCount > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      itemCount > 9 ? '9+' : '$itemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          ),
        );
      },
    );
  }
}