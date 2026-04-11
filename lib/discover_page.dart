import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_detail_page.dart';
import 'favorites_page.dart';
import 'cart_page.dart';
import 'cart_icon_badge.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
      title: const Text('Discover'),
      backgroundColor: Colors.green.shade50,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const FavoritesPage())),
          ),
          IconButton(
            icon: const CartIconBadge(),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const CartPage())),
          ),
        ],
      ),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('businesses').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final businesses = docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['businessId'] = doc.id;
                    return data;
                  }).toList();

                  final filtered = businesses.where((b) {
                    final name = (b['name'] ?? '').toString().toLowerCase();
                    return name.contains(searchQuery.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final seller = filtered[index];

                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BusinessDetailPage(seller: seller),
                            ),
                          );
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
                                        seller['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.navigation_rounded),
                                      onPressed: () {},
                                    ),
                                  ],
                                ),
                                Text(
                                  seller['address'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color.fromARGB(255, 141, 141, 141),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}