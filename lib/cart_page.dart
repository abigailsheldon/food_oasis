import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/firestore_service.dart';
import 'checkout_page.dart';
import 'app_bottom_nav.dart';
import 'business_detail_page.dart';
import 'pickup_time_selector.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final FirestoreService _firestoreService = FirestoreService();
  
  // Cache for business names and availability
  Map<String, String> _businessNames = {};
  Map<String, Map<String, dynamic>> _businessData = {};
  Map<String, bool> _businessAvailability = {};

  void _incrementItem(Map<String, dynamic> item) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('cart')
        .doc(item['cartItemId'])
        .update({
      'quantity': FieldValue.increment(1),
    });
  }

  void _decrementItem(Map<String, dynamic> item) async {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('cart')
        .doc(item['cartItemId']);

    if (item['quantity'] > 1) {
      await docRef.update({
        'quantity': FieldValue.increment(-1),
      });
    } else {
      await docRef.delete();
    }
  }

  void _removeItem(Map<String, dynamic> item) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('cart')
        .doc(item['cartItemId'])
        .delete();
  }

  Future<Map<String, dynamic>> _getBusinessInfo(String businessId) async {
    if (_businessData.containsKey(businessId)) {
      return _businessData[businessId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Unknown Seller';
        final accepting = data['acceptingReservations'] ?? true;
        
        _businessNames[businessId] = name;
        _businessAvailability[businessId] = accepting;
        _businessData[businessId] = {...data, 'businessId': businessId};
        
        return _businessData[businessId]!;
      }
    } catch (e) {
      // Handle error
    }

    _businessNames[businessId] = 'Unknown Seller';
    _businessAvailability[businessId] = true;
    _businessData[businessId] = {'name': 'Unknown Seller', 'businessId': businessId};
    return _businessData[businessId]!;
  }

  Future<bool> _isBusinessAccepting(String businessId) async {
    await _getBusinessInfo(businessId);
    return _businessAvailability[businessId] ?? true;
  }

  // Group cart items by businessId
  Map<String, List<Map<String, dynamic>>> _groupByVendor(List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final item in items) {
      final businessId = item['businessId'] ?? 'unknown';
      if (!grouped.containsKey(businessId)) {
        grouped[businessId] = [];
      }
      grouped[businessId]!.add(item);
    }
    
    return grouped;
  }

  // Calculate subtotal for a vendor's items
  double _calculateVendorSubtotal(List<Map<String, dynamic>> items) {
    return items.fold(0, (sum, item) {
      return sum + (item['price'] * item['quantity']);
    });
  }

  // Remove all items from unavailable vendors
  Future<void> _removeUnavailableItems(Map<String, List<Map<String, dynamic>>> groupedItems) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    
    for (final entry in groupedItems.entries) {
      final businessId = entry.key;
      final isAvailable = await _isBusinessAccepting(businessId);
      
      if (!isAvailable) {
        for (final item in entry.value) {
          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('cart')
              .doc(item['cartItemId']);
          batch.delete(docRef);
        }
      }
    }

    await batch.commit();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unavailable items removed from cart'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        backgroundColor: Colors.green.shade50,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getCartStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cartItems = snapshot.data ?? [];

          if (cartItems.isEmpty) {
            return Center(
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
            );
          }

          // Group items by vendor
          final groupedItems = _groupByVendor(cartItems);
          final vendorIds = groupedItems.keys.toList();

          return FutureBuilder<Map<String, bool>>(
            future: _checkAllVendorsAvailability(vendorIds),
            builder: (context, availabilitySnapshot) {
              final availabilityMap = availabilitySnapshot.data ?? {};
              
              // Check if any vendors are unavailable
              final hasUnavailableItems = availabilityMap.values.any((available) => !available);
              
              // Calculate totals
              double totalPrice = cartItems.fold(0, (sum, item) {
                return sum + (item['price'] * item['quantity']);
              });

              // Calculate available items total only
              double availableTotal = 0;
              int unavailableCount = 0;
              for (final entry in groupedItems.entries) {
                final isAvailable = availabilityMap[entry.key] ?? true;
                if (isAvailable) {
                  availableTotal += _calculateVendorSubtotal(entry.value);
                } else {
                  unavailableCount += entry.value.length;
                }
              }

              return Column(
                children: [
                  // Warning banner if items are unavailable
                  if (hasUnavailableItems)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.orange.shade100,
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                            color: Colors.orange.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$unavailableCount item${unavailableCount > 1 ? 's' : ''} unavailable',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                                Text(
                                  'Some sellers are not accepting orders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _removeUnavailableItems(groupedItems),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: vendorIds.length,
                      itemBuilder: (context, vendorIndex) {
                        final businessId = vendorIds[vendorIndex];
                        final vendorItems = groupedItems[businessId]!;
                        final vendorSubtotal = _calculateVendorSubtotal(vendorItems);
                        final isAvailable = availabilityMap[businessId] ?? true;

                        return _buildVendorSection(
                          businessId: businessId,
                          items: vendorItems,
                          subtotal: vendorSubtotal,
                          isAvailable: isAvailable,
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
                        // Show number of vendors
                        if (vendorIds.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Items from ${vendorIds.length} sellers',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        
                        // Show available total if some items unavailable
                        if (hasUnavailableItems) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Unavailable items',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              Text(
                                '\$${(totalPrice - availableTotal).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

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
                              '\$${(hasUnavailableItems ? availableTotal : totalPrice).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Checkout button - disabled if all items unavailable
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (hasUnavailableItems && availableTotal == 0)
                                ? null
                                : () {
                                    if (hasUnavailableItems) {
                                      // Show confirmation dialog
                                      _showCheckoutConfirmation(
                                        context, 
                                        groupedItems,
                                        availabilityMap,
                                        availableTotal,
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const CheckoutPage(),
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              disabledForegroundColor: Colors.grey.shade500,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              hasUnavailableItems 
                                  ? (availableTotal > 0 
                                      ? 'Checkout Available Items' 
                                      : 'No Items Available')
                                  : 'Proceed to Checkout',
                              style: const TextStyle(
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
              );
            },
          );
        },
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }

  Future<Map<String, bool>> _checkAllVendorsAvailability(List<String> vendorIds) async {
    final Map<String, bool> result = {};
    for (final id in vendorIds) {
      result[id] = await _isBusinessAccepting(id);
    }
    return result;
  }

  void _showCheckoutConfirmation(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> groupedItems,
    Map<String, bool> availabilityMap,
    double availableTotal,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Some Items Unavailable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Some items in your cart are from sellers not currently accepting orders.',
            ),
            const SizedBox(height: 12),
            Text(
              'You can checkout with available items only (\$${availableTotal.toStringAsFixed(2)}).',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unavailable items will be removed from your cart.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
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
              Navigator.pop(context);
              // Remove unavailable items first
              await _removeUnavailableItems(groupedItems);
              // Then go to checkout
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CheckoutPage(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSection({
    required String businessId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required bool isAvailable,
  }) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isAvailable ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable ? Colors.grey.shade200 : Colors.orange.shade200,
            width: isAvailable ? 1 : 2,
          ),
          boxShadow: isAvailable ? [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Header
            FutureBuilder<Map<String, dynamic>>(
              future: _getBusinessInfo(businessId),
              builder: (context, snapshot) {
                final businessName = snapshot.data?['name'] ?? 'Loading...';
                
                return InkWell(
                  onTap: () {
                    if (_businessData.containsKey(businessId)) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BusinessDetailPage(
                            seller: _businessData[businessId]!,
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isAvailable ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAvailable ? Icons.storefront : Icons.store_outlined,
                          size: 20,
                          color: isAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isAvailable ? Colors.green.shade800 : Colors.orange.shade800,
                                ),
                              ),
                              if (!isAvailable)
                                Text(
                                  'Not accepting orders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              'UNAVAILABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.green.shade600,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Items list
            ...items.map((item) => _buildCartItemCard(item, isAvailable: isAvailable)),

            // Vendor Subtotal
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isAvailable ? Colors.grey.shade50 : Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subtotal (${items.length} ${items.length == 1 ? 'item' : 'items'})',
                    style: TextStyle(
                      fontSize: 14,
                      color: isAvailable ? Colors.grey.shade700 : Colors.orange.shade700,
                      decoration: isAvailable ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '\$${subtotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                      decoration: isAvailable ? null : TextDecoration.lineThrough,
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

  Widget _buildCartItemCard(Map<String, dynamic> item, {required bool isAvailable}) {
    // Parse pickup time and check if expired
    String? pickupTimeStr;
    bool isExpired = false;
    DateTime? pickupDateTime;
    
    final pickupTime = item['pickupTime'];
    if (pickupTime != null) {
      if (pickupTime is Timestamp) {
        pickupDateTime = pickupTime.toDate();
      } else {
        pickupDateTime = pickupTime as DateTime;
      }
      
      // Check if pickup time has passed
      isExpired = pickupDateTime.isBefore(DateTime.now());
      
      final hour = pickupDateTime.hour > 12 ? pickupDateTime.hour - 12 : (pickupDateTime.hour == 0 ? 12 : pickupDateTime.hour);
      final minute = pickupDateTime.minute.toString().padLeft(2, '0');
      final period = pickupDateTime.hour >= 12 ? 'PM' : 'AM';
      final month = pickupDateTime.month;
      final day = pickupDateTime.day;
      pickupTimeStr = '$month/$day at $hour:$minute $period';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.shade50 : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Item icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isExpired 
                      ? Colors.red.shade100 
                      : (isAvailable ? Colors.green.shade100 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isExpired ? Icons.timer_off : Icons.shopping_bag,
                  size: 26,
                  color: isExpired ? Colors.red : (isAvailable ? Colors.green : Colors.grey),
                ),
              ),
              const SizedBox(width: 12),

              // Item info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isExpired ? Colors.red.shade800 : (isAvailable ? Colors.black : Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${item['price'].toStringAsFixed(2)} / ${item['unit'] ?? 'ea'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    // Pickup time
                    if (pickupTimeStr != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isExpired ? Icons.warning : Icons.schedule,
                            size: 14,
                            color: isExpired ? Colors.red.shade600 : Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired ? 'EXPIRED: $pickupTimeStr' : 'Pickup: $pickupTimeStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired ? Colors.red.shade700 : Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Quantity controls or remove button
              if (!isExpired && isAvailable)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _decrementItem(item),
                      icon: Icon(
                        item['quantity'] > 1
                            ? Icons.remove_circle_outline
                            : Icons.delete_outline,
                        color: Colors.red.shade400,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        item['quantity'].toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _incrementItem(item),
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: Colors.green.shade700,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                )
              else if (!isExpired)
                // Just show remove button for unavailable items
                TextButton.icon(
                  onPressed: () => _removeItem(item),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          
          // Expired item action buttons
          if (isExpired) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This pickup time has passed. Please update or remove.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updatePickupTime(item),
                          icon: const Icon(Icons.edit_calendar, size: 16),
                          label: const Text('Update Time'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _removeItem(item),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Remove'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade400),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Future<void> _updatePickupTime(Map<String, dynamic> item) async {
    final businessId = item['businessId'] ?? '';
    
    if (businessId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update pickup time')),
      );
      return;
    }
    
    final newPickupTime = await PickupTimeSelector.show(
      context: context,
      businessId: businessId,
    );
    
    if (newPickupTime != null) {
      // Update the cart item with new pickup time
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('cart')
          .doc(item['cartItemId'])
          .update({
        'pickupTime': Timestamp.fromDate(newPickupTime),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pickup time updated for ${item['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}