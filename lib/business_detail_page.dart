import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cart_page.dart';
import 'app_bottom_nav.dart';
import 'pickup_time_selector.dart';

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
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

                      // RATING SUMMARY
                      _buildRatingSummary(),

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

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 8),

                      // REVIEWS SECTION
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reviews',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showWriteReviewDialog(),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Write a Review'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _buildReviewsSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }

  // RATING SUMMARY (shows average stars next to business name)
  Widget _buildRatingSummary() {
    final businessId = widget.seller['businessId'] ?? '';
    if (businessId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No reviews yet',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          );
        }

        final reviews = snapshot.data!.docs;
        double totalRating = 0;
        for (var doc in reviews) {
          final data = doc.data() as Map<String, dynamic>;
          totalRating += (data['rating'] ?? 0).toDouble();
        }
        final averageRating = totalRating / reviews.length;

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < averageRating.round() ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                );
              }),
              const SizedBox(width: 8),
              Text(
                '${averageRating.toStringAsFixed(1)} (${reviews.length})',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        );
      },
    );
  }

  // REVIEWS SECTION
  Widget _buildReviewsSection() {
    final businessId = widget.seller['businessId'] ?? '';
    if (businessId.isEmpty) {
      return const Text('Unable to load reviews');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reviews = snapshot.data!.docs;

        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No reviews yet',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to leave a review!',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return Column(
          children: reviews.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final rating = (data['rating'] ?? 0).toInt();
            final comment = data['comment'] ?? '';
            final reviewerName = data['reviewerName'] ?? 'Anonymous';
            final createdAt = data['createdAt'] as Timestamp?;
            final date = createdAt?.toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green.shade100,
                              child: Text(
                                reviewerName.isNotEmpty 
                                    ? reviewerName[0].toUpperCase() 
                                    : 'A',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reviewerName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (date != null)
                                  Text(
                                    '${date.month}/${date.day}/${date.year}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              i < rating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 16,
                            );
                          }),
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // WRITE REVIEW DIALOG
  void _showWriteReviewDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to leave a review')),
      );
      return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Write a Review'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Star Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () {
                          setDialogState(() {
                            selectedRating = i + 1;
                          });
                        },
                        icon: Icon(
                          i < selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  // Comment
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Share your experience...',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _submitReview(selectedRating, commentController.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // SUBMIT REVIEW TO FIRESTORE
  Future<void> _submitReview(int rating, String comment) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final businessId = widget.seller['businessId'] ?? '';
    if (businessId.isEmpty) return;

    // Get user's name from Firestore
    String reviewerName = 'Anonymous';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      reviewerName = userDoc.data()?['name'] ?? user.email?.split('@')[0] ?? 'Anonymous';
    } catch (e) {
      reviewerName = user.email?.split('@')[0] ?? 'Anonymous';
    }

    await FirebaseFirestore.instance.collection('reviews').add({
      'businessId': businessId,
      'reviewerId': user.uid,
      'reviewerName': reviewerName,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review submitted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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

        // Apply search filter
        final filteredDocs = docs.where((doc) {
          if (searchQuery.isEmpty) return true;
          
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().toLowerCase();
          
          return name.contains(searchQuery.toLowerCase()) ||
                 description.contains(searchQuery.toLowerCase()) ||
                 category.contains(searchQuery.toLowerCase());
        }).toList();

        // GROUP BY CATEGORY
        Map<String, List<Map<String, dynamic>>> categorizedItems = {};

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          data['productId'] = doc.id;

          final rawCategory = (data['category'] ?? '').toString().trim();

          final category = rawCategory.isEmpty
              ? 'Other'
              : rawCategory[0].toUpperCase() + rawCategory.substring(1).toLowerCase();

          if (!categorizedItems.containsKey(category)) {
            categorizedItems[category] = [];
          }

          categorizedItems[category]!.add(data);
        }

        final sortedKeys = categorizedItems.keys.toList()..sort();

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

        // Show message if search has no results but products exist
        if (filteredDocs.isEmpty && searchQuery.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No items match "$searchQuery"',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedKeys.map((category) {
            final items = categorizedItems[category]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CATEGORY HEADER
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // ITEMS UNDER CATEGORY
                ...items.map((item) => _buildItemCard(item)).toList(),

                const SizedBox(height: 12),
              ],
            );
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
              onPressed: () async {
                // Show pickup time selector
                final pickupTime = await PickupTimeSelector.show(
                  context: context,
                  businessId: sellerId,
                );

                if (pickupTime != null) {
                  await _firestoreService.addToCartWithPickupTime(item, pickupTime);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${item['name']} added to cart!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
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
                  onPressed: () async {
                    Navigator.pop(context);
                    
                    // Show pickup time selector
                    final pickupTime = await PickupTimeSelector.show(
                      context: context,
                      businessId: sellerId,
                    );

                    if (pickupTime != null) {
                      await _firestoreService.addToCartWithPickupTime(item, pickupTime);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item['name']} added to cart!'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
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