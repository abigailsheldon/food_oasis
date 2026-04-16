import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_bottom_nav.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardNicknameController = TextEditingController();

  String selectedPayment = 'Credit Card';
  String? selectedSavedCard;
  bool saveCard = false;
  bool useNewCard = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardNicknameController.dispose();
    super.dispose();
  }

  String _detectCardType(String cardNumber) {
    final number = cardNumber.replaceAll(RegExp(r'\D'), '');
    
    if (number.startsWith('4')) {
      return 'Visa';
    } else if (number.startsWith('5') || 
               (number.length >= 4 && (int.tryParse(number.substring(0, 4)) ?? 0) >= 2221 &&
               (int.tryParse(number.substring(0, 4)) ?? 0) <= 2720)) {
      return 'Mastercard';
    } else if (number.startsWith('34') || number.startsWith('37')) {
      return 'Amex';
    } else if (number.startsWith('6011') || 
               number.startsWith('65') ||
               number.startsWith('644') ||
               number.startsWith('645') ||
               number.startsWith('646') ||
               number.startsWith('647') ||
               number.startsWith('648') ||
               number.startsWith('649')) {
      return 'Discover';
    }
    return 'Card';
  }

  Future<void> _saveCardToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    if (cardNumber.length < 4) return;

    final lastFour = cardNumber.substring(cardNumber.length - 4);
    final cardType = _detectCardType(cardNumber);
    final nickname = _cardNicknameController.text.trim().isNotEmpty
        ? _cardNicknameController.text.trim()
        : '$cardType •••• $lastFour';

    // Check if this should be default (first card)
    final existingCards = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedCards')
        .get();
    
    final isDefault = existingCards.docs.isEmpty;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedCards')
        .add({
      'nickname': nickname,
      'lastFour': lastFour,
      'cardType': cardType,
      'holderName': _nameController.text.trim(),
      'expiry': _expiryController.text,
      'isDefault': isDefault,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _placeOrder() async {
    // Save card if checkbox is checked
    if (saveCard && useNewCard) {
      await _saveCardToFirestore();
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');

      final cartSnapshot = await cartRef.get();
      
      if (cartSnapshot.docs.isNotEmpty) {
        // Build order items list
        final List<Map<String, dynamic>> orderItems = [];
        double orderTotal = 0;

        for (var doc in cartSnapshot.docs) {
          final item = doc.data();
          orderItems.add({
            'productId': item['productId'] ?? '',
            'businessId': item['businessId'] ?? '',
            'name': item['name'] ?? '',
            'price': item['price'] ?? 0,
            'quantity': item['quantity'] ?? 1,
            'unit': item['unit'] ?? '',
            'iconKey': item['iconKey'] ?? '',
            'pickupTime': item['pickupTime'],
            'itemStatus': 'pending', // For seller to mark as ready
          });
          orderTotal += (item['price'] ?? 0) * (item['quantity'] ?? 1);
        }

        // Generate a shared order ID
        final orderRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('orders')
            .doc();
        final orderId = orderRef.id;

        // Get buyer info
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data() ?? {};
        final buyerName = userData['name'] ?? user.email?.split('@')[0] ?? 'Customer';
        final buyerEmail = user.email ?? '';

        // Save order to buyer's orders
        await orderRef.set({
          'items': orderItems,
          'total': orderTotal,
          'status': 'pending', // Changed from 'completed' to 'pending'
          'deliveryAddress': '${_addressController.text}, ${_cityController.text}',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Group items by businessId for seller orders
        final Map<String, List<Map<String, dynamic>>> itemsByBusiness = {};
        for (var item in orderItems) {
          final businessId = item['businessId'] ?? '';
          if (businessId.isNotEmpty) {
            itemsByBusiness.putIfAbsent(businessId, () => []);
            itemsByBusiness[businessId]!.add(item);
          }
        }

        // Create seller order for each business
        for (var entry in itemsByBusiness.entries) {
          final businessId = entry.key;
          final businessItems = entry.value;
          
          // Calculate subtotal for this seller
          double sellerTotal = 0;
          for (var item in businessItems) {
            sellerTotal += (item['price'] ?? 0) * (item['quantity'] ?? 1);
          }

          await FirebaseFirestore.instance
              .collection('sellerOrders')
              .doc(businessId)
              .collection('orders')
              .doc(orderId) // Use same orderId for reference
              .set({
            'orderId': orderId,
            'buyerId': user.uid,
            'buyerName': buyerName,
            'buyerEmail': buyerEmail,
            'items': businessItems,
            'subtotal': sellerTotal,
            'deliveryAddress': '${_addressController.text}, ${_cityController.text}',
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Clear cart after saving order
        for (var doc in cartSnapshot.docs) {
          await doc.reference.delete();
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Order Placed!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your order has been successfully placed.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Back to Shop',
                style: TextStyle(color: Colors.green.shade700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.green.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Info Section
            _sectionHeader(Icons.local_shipping_outlined, 'Delivery Information'),
            const SizedBox(height: 12),
            _buildTextField(_nameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 10),
            _buildTextField(_emailController, 'Email', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _buildTextField(
                _addressController, 'Street Address', Icons.home_outlined),
            const SizedBox(height: 10),
            _buildTextField(_cityController, 'City, State, ZIP',
                Icons.location_city_outlined),
            const SizedBox(height: 24),

            // Payment Section
            _sectionHeader(Icons.payment_outlined, 'Payment Method'),
            const SizedBox(height: 12),

            // Saved Cards
            _buildSavedCardsSection(),

            const SizedBox(height: 16),

            // Use new card toggle
            GestureDetector(
              onTap: () {
                setState(() {
                  useNewCard = true;
                  selectedSavedCard = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: useNewCard ? Colors.green.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: useNewCard ? Colors.green : Colors.grey.shade300,
                    width: useNewCard ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      useNewCard ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: useNewCard ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    const Text('Use a new card', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Only show new card form if useNewCard is true
            if (useNewCard) ...[
              // Payment toggle
              Row(
              children: ['Credit Card', 'Debit Card'].map((method) {
                final selected = selectedPayment == method;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedPayment = method),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.green.shade600
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? Colors.green.shade600
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        method,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            // Card Number with auto-formatting
            TextField(
              controller: _cardNumberController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card, color: Colors.green.shade600),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                counterText: '', // Hide character counter
              ),
              onChanged: (value) {
                // Auto-format with spaces every 4 digits
                final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                final formatted = digitsOnly.replaceAllMapped(
                  RegExp(r'.{4}'),
                  (match) => '${match.group(0)} ',
                ).trim();
                if (formatted != value) {
                  _cardNumberController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  // Expiry with auto-formatting MM/YY
                  child: TextField(
                    controller: _expiryController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: InputDecoration(
                      labelText: 'MM/YY',
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.calendar_today, color: Colors.green.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      counterText: '', // Hide character counter
                    ),
                    onChanged: (value) {
                      // Auto-format MM/YY
                      final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                      String formatted = digitsOnly;
                      if (digitsOnly.length >= 2) {
                        formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
                      }
                      if (formatted != value) {
                        _expiryController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  // CVV with obscured text
                  child: TextField(
                    controller: _cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      hintText: '•••',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.green.shade600),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green.shade600, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      counterText: '', // Hide character counter
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Save card checkbox
            Row(
              children: [
                Checkbox(
                  value: saveCard,
                  onChanged: (value) => setState(() => saveCard = value ?? false),
                  activeColor: Colors.green,
                ),
                const Text('Save this card for future purchases'),
              ],
            ),

            if (saveCard) ...[
              const SizedBox(height: 8),
              _buildTextField(_cardNicknameController, 'Card nickname (optional)', Icons.label_outline),
            ],
            ], // Close the if (useNewCard) block

            const SizedBox(height: 32),
          
            // Place Order button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Place Order',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.green.shade700, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade600, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildSavedCardsSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedCards')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final cards = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saved Cards', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            ...cards.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cardId = doc.id;
              final isSelected = selectedSavedCard == cardId;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSavedCard = cardId;
                    useNewCard = false;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: isSelected ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.green : Colors.grey),
                      const SizedBox(width: 12),
                      Icon(Icons.credit_card, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['nickname'] ?? 'Saved Card', style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text('•••• ${data['lastFour']} | Exp: ${data['expiry']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('savedCards').doc(cardId).delete();
                          if (selectedSavedCard == cardId) {
                            setState(() {
                              selectedSavedCard = null;
                              useNewCard = true;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }
}