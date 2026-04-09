import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_page.dart';

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
    final seller = widget.seller;

    final String name = seller['name'] ?? 'Unnamed Business';
    final String address = seller['address'] ?? '';
    final String description = seller['description'] ?? '';
    final String locationDetails = seller['locationDetails'] ?? '';
    final String certifications = seller['certifications'] ?? '';
    final String paymentMethods = seller['paymentMethods'] ?? '';
    final String foodAssistance = seller['foodAssistance'] ?? '';
    final String products = seller['products'] ?? '';
    final String seasonality = seller['seasonality'] ?? '';
    final String phone = seller['phone'] ?? '';
    final String email = seller['email'] ?? '';
    final String website = seller['website'] ?? '';
    final String directory = seller['directory'] ?? '';
    final String source = seller['source'] ?? '';

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
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartPage()),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (directory.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    directory,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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

                  const SizedBox(height: 16),

                  // Address
                  if (address.isNotEmpty)
                    _buildInfoRow(Icons.location_on, address),

                  // Location details
                  if (locationDetails.isNotEmpty)
                    _buildInfoRow(Icons.info_outline, locationDetails),

                  // Seasonality
                  if (seasonality.isNotEmpty)
                    _buildInfoRow(Icons.calendar_today, 'Season: $seasonality'),

                  // Phone
                  if (phone.isNotEmpty)
                    _buildTappableRow(Icons.phone, phone, () => _launchUrl('tel:$phone')),

                  // Email
                  if (email.isNotEmpty)
                    _buildTappableRow(Icons.email, email, () => _launchUrl('mailto:$email')),

                  // Website
                  if (website.isNotEmpty)
                    _buildTappableRow(
                      Icons.language,
                      website,
                      () => _launchUrl(website.startsWith('http') ? website : 'https://$website'),
                    ),

                  const SizedBox(height: 16),

                  // Description
                  if (description.isNotEmpty && description != 'Local food vendor from USDA directory') ...[
                    const Text('About', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                    const SizedBox(height: 16),
                  ],

                  // Certifications
                  if (certifications.isNotEmpty)
                    _buildTagSection('Certifications', Icons.verified, certifications, Colors.blue),

                  // Payment Methods
                  if (paymentMethods.isNotEmpty)
                    _buildTagSection('Payment Methods', Icons.payment, paymentMethods, Colors.purple),

                  // Food Assistance
                  if (foodAssistance.isNotEmpty)
                    _buildTagSection('Food Assistance Accepted', Icons.card_giftcard, foodAssistance, Colors.orange),

                  // Products
                  if (products.isNotEmpty)
                    _buildTagSection('Products Available', Icons.shopping_basket, products, Colors.green),

                  const Divider(),
                  const SizedBox(height: 8),

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
    final String ownerUid = widget.seller['ownerUid'] ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter products that match either businessId or ownerUid
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final productBusinessId = data['businessId'] ?? '';
          return productBusinessId == businessId || productBusinessId == ownerUid;
        }).toList();

        if (docs.isEmpty) {
          final source = widget.seller['source'] ?? '';

          if (source == 'USDA') {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This vendor is from the USDA directory. Visit their location or contact them directly for available items.',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }

          return const Padding(
            padding: EdgeInsets.all(20),
            child: Text("No products available", style: TextStyle(color: Colors.grey)),
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
    Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableRow(IconData icon, String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 14, color: Colors.green.shade700, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSection(String title, IconData icon, String data, Color color) {
    final items = data.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(item, style: TextStyle(fontSize: 12, color: color)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}