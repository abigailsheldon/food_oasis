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

  Future<void> _saveCardToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    if (cardNumber.length < 4) return;

    final lastFour = cardNumber.substring(cardNumber.length - 4);
    final nickname = _cardNicknameController.text.isNotEmpty
        ? _cardNicknameController.text
        : '$selectedPayment ending in $lastFour';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('savedCards')
        .add({
      'nickname': nickname,
      'lastFour': lastFour,
      'expiry': _expiryController.text,
      'cardType': selectedPayment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _placeOrder() async {
    // Save card if checkbox is checked
    if (saveCard && useNewCard) {
      await _saveCardToFirestore();
    }

    // Clear cart after order
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final cartRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart');
      final cartItems = await cartRef.get();
      for (var doc in cartItems.docs) {
        await doc.reference.delete();
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
            _buildTextField(
                _cardNumberController, 'Card Number', Icons.credit_card,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                      _expiryController, 'MM/YY', Icons.calendar_today,
                      keyboardType: TextInputType.number),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(_cvvController, 'CVV', Icons.lock_outline,
                      keyboardType: TextInputType.number),
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

