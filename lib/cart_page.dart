import 'package:flutter/material.dart';
import 'item_data.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Placeholder cart items for UI testing: item id -> quantity
  final Map<String, int> cartQuantities = {
    '2': 1,
    '4': 2,
    '7': 1,
  };

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

  double get totalPrice {
    double total = 0;
    for (final item in shopItems) {
      if (cartQuantities.containsKey(item['id'])) {
        total += item['price'] * cartQuantities[item['id']]!;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final cartItems =
        shopItems.where((item) => cartQuantities.containsKey(item['id'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        backgroundColor: Colors.green.shade50,
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add items from the shop to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final quantity = cartQuantities[item['id']]!;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              // Item icon
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  getItemIcon(item['imageIcon']),
                                  size: 32,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Item info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['seller'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '\$${item['price'].toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Quantity controls
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        if (quantity > 1) {
                                          cartQuantities[item['id']] =
                                              quantity - 1;
                                        } else {
                                          cartQuantities.remove(item['id']);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      quantity > 1
                                          ? Icons.remove_circle_outline
                                          : Icons.delete_outline,
                                      color: Colors.red.shade400,
                                    ),
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        cartQuantities[item['id']] =
                                            quantity + 1;
                                      });
                                    },
                                    icon: Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Order summary + checkout
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CheckoutPage(),
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
                            'Proceed to Checkout',
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
    );
  }
}