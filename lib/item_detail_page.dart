import 'package:flutter/material.dart';
import 'seller_data.dart';
import 'discover_detail_page.dart';


class ItemDetailPage extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailPage({super.key, required this.item});

  // Map icon names to actual icons
  IconData getItemIcon(String iconName) {
    switch (iconName) {
      case 'apple':
        return Icons.apple;
      case 'lunch_dining':
        return Icons.lunch_dining;
      case 'local_drink':
        return Icons.local_drink;
      case 'takeout_dining':
        return Icons.takeout_dining;
      case 'bakery_dining':
        return Icons.bakery_dining;
      case 'cookie':
        return Icons.cookie;
      case 'egg':
        return Icons.egg;
      case 'blender':
        return Icons.blender;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item['name']),
        backgroundColor: Colors.green.shade50,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item image/icon header
            Container(
              width: double.infinity,
              height: 200,
              color: Colors.green.shade100,
              child: Icon(
                getItemIcon(item['imageIcon']),
                size: 100,
                color: Colors.green.shade700,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item name
                  Text(
                    item['name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Seller info row
                  Row(
                    children: [
                      Icon(Icons.storefront, 
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        item['seller'],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Price
                  Text(
                    '\$${item['price'].toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description section
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tags
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (item['tags'] as List<String>)
                        .map(
                          (tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.green.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.green.shade300),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 30),

                  // Add to Cart button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item['name']} added to cart!'),
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

                  // View Seller button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        // Find the seller from seller_data
                        final seller = sellers.firstWhere(
                          (s) => s['businessName'] == item['seller'],
                          orElse: () => <String, dynamic>{},
                        );

                        if (seller.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DiscoverDetailPage(seller: seller),
                            ),
                          );
                        } else {                        
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('View ${item['seller']} coming soon!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
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