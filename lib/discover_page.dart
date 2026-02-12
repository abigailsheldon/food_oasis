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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: filteredSellers.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(filteredSellers[index]),
                    onTap: () {
                      // Navigate to seller details page
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
}