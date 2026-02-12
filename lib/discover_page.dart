import 'package:flutter/material.dart';
import 'seller_data.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}
class _DiscoverPageState extends State<DiscoverPage> {
  final List<String> sellers = healthySellers
      .map((seller) => seller['businessName'] as String)
      .toList();
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredSellers = sellers
        .where((seller) =>
            seller.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Search for sellers',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: filteredSellers.length,
                itemBuilder: (context, index) {
                  final seller = healthySellers.firstWhere(
                    (s) => s['businessName'] == filteredSellers[index],
                  );

                  return InkWell(
                    onTap: () {
                      // will navigate to seller details page
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    seller['businessName'] as String,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.navigation_rounded),
                                  onPressed: () {
                                    // Navigate to seller details page
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: (seller['tags'] as List<String>)
                                  .map(
                                    (tag) => Chip(
                                      label: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      backgroundColor: Theme.of(context).cardColor,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
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