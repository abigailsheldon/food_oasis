import 'package:flutter/material.dart';
import 'item_data.dart';
import 'item_detail_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String searchQuery = '';

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
    final filteredItems = shopItems
        .where((item) =>
            item['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            item['seller'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            (item['tags'] as List<String>).any(
                (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase())))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        backgroundColor: Colors.green.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search bar
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
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 12),

            // Items grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];

                  return GestureDetector(
                    onTap: () {
                      // Navigate to item detail page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemDetailPage(item: item),
                        ),
                      );
                    },
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item icon/image placeholder
                            Expanded(
                              flex: 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  getItemIcon(item['imageIcon']),
                                  size: 32,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Item name
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Seller name
                            Text(
                              item['seller'],
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),

                            // Price
                            Text(
                              '\$${item['price'].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}