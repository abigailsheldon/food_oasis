import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_item_page.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'auth/seller_signup_page.dart';
import 'seller_reviews_page.dart';
import 'app_bottom_nav.dart';
import 'product_icons.dart';
import 'main.dart'; // Import for AuthWrapper


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? businessId;
  String? role;

  bool isLoading = true;

  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _authService.currentUser?.uid;

    if (uid == null) {
      setState(() => isLoading = false);
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    final data = doc.data();

    role = data?['role'];
    businessId = data?['businessId'];

    setState(() => isLoading = false);
  }

  // Cache for business names in purchase history
  Map<String, String> _purchaseHistoryBusinessNames = {};

  Future<String> _getBusinessNameForHistory(String businessId) async {
    if (_purchaseHistoryBusinessNames.containsKey(businessId)) {
      return _purchaseHistoryBusinessNames[businessId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (doc.exists) {
        final name = doc.data()?['name'] ?? 'Unknown Seller';
        _purchaseHistoryBusinessNames[businessId] = name;
        return name;
      }
    } catch (e) {
      // Handle error
    }

    _purchaseHistoryBusinessNames[businessId] = 'Unknown Seller';
    return 'Unknown Seller';
  }

  // Group items by businessId
  Map<String, List<Map<String, dynamic>>> _groupItemsByVendor(List<dynamic> items) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final item in items) {
      final itemData = item as Map<String, dynamic>;
      final businessId = itemData['businessId'] ?? 'unknown';
      if (!grouped.containsKey(businessId)) {
        grouped[businessId] = [];
      }
      grouped[businessId]!.add(itemData);
    }
    
    return grouped;
  }

  Widget _buildPurchaseHistory() {
    final user = _authService.currentUser;
    if (user == null) {
      return const Text('Please log in to view purchase history');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;

        if (orders.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No orders yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your purchase history will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return Column(
          children: orders.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final items = (data['items'] as List<dynamic>?) ?? [];
            final total = (data['total'] ?? 0).toDouble();
            final status = data['status'] ?? 'completed';
            final createdAt = data['createdAt'] as Timestamp?;
            final date = createdAt?.toDate();

            // Group items by vendor
            final groupedItems = _groupItemsByVendor(items);
            final vendorCount = groupedItems.keys.length;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
                ),
                title: Text(
                  '\$${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          date != null
                              ? '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                              : 'Date unknown',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (vendorCount > 1)
                          Text(
                            '• $vendorCount sellers',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'completed' ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: status == 'completed' ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Grouped by vendor
                  ...groupedItems.entries.map((entry) {
                    final businessId = entry.key;
                    final vendorItems = entry.value;
                    final vendorSubtotal = vendorItems.fold<double>(
                      0,
                      (sum, item) => sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vendor header
                          FutureBuilder<String>(
                            future: _getBusinessNameForHistory(businessId),
                            builder: (context, snapshot) {
                              final businessName = snapshot.data ?? 'Loading...';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.storefront, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        businessName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '\$${vendorSubtotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // Vendor items
                          ...vendorItems.map((itemData) {
                            // Format pickup time if available
                            String? pickupTimeStr;
                            final pickupTime = itemData['pickupTime'];
                            if (pickupTime != null) {
                              DateTime dt;
                              if (pickupTime is Timestamp) {
                                dt = pickupTime.toDate();
                              } else {
                                dt = pickupTime as DateTime;
                              }
                              final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                              final minute = dt.minute.toString().padLeft(2, '0');
                              final period = dt.hour >= 12 ? 'PM' : 'AM';
                              pickupTimeStr = '${dt.month}/${dt.day} at $hour:$minute $period';
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.fastfood, size: 18, color: Colors.grey),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemData['name'] ?? 'Unknown item',
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Qty: ${itemData['quantity']} × \$${(itemData['price'] ?? 0).toStringAsFixed(2)}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                        if (pickupTimeStr != null)
                                          Row(
                                            children: [
                                              Icon(Icons.schedule, size: 12, color: Colors.blue.shade600),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Pickup: $pickupTimeStr',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '\$${((itemData['price'] ?? 0) * (itemData['quantity'] ?? 1)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    );
                  }).toList(),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ---------------- BUYER DASHBOARD ----------------
    if (role == "buyer") {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Buyer Dashboard'),
          backgroundColor: Colors.green.shade50,
          actions: [

            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () async {
                await _authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),

        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ================= HEADER CARD =================
              Card(
                elevation: 0,
                color: Colors.green.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.green.shade200,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "My Account",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Manage orders, payments, and preferences",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _showBuyerSettings(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ================= SELLER ENTRY CARD =================
              Card(
                child: ListTile(
                  leading: Icon(Icons.storefront, color: Colors.green.shade700),
                  title: const Text('Become a Seller'),
                  subtitle: const Text('Start selling your products'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SellerOnboardingPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ================= PAYMENT METHODS CARD =================
              Card(
                child: ListTile(
                  leading: Icon(Icons.credit_card, color: Colors.blue.shade700),
                  title: const Text('Payment Methods'),
                  subtitle: const Text('Manage your saved cards'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSavedCards(context),
                ),
              ),
              const SizedBox(height: 24),

              // ================= PURCHASE HISTORY =================
              const Text(
                'Purchase History',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildPurchaseHistory(),
            ],
          ),
        ),
      );
    }
    // ---------------- SELLER DASHBOARD ----------------
    return SellerDashboardPage(
      businessId: businessId,
      firestoreService: _firestoreService,
      authService: _authService,
    );
  }
  void _showBuyerSettings(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((doc) {
      if (doc.exists) {
        nameController.text = doc.data()?['name'] ?? '';
        phoneController.text = doc.data()?['phone'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: user.email),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings updated')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSavedCards(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddCardDialog(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Card'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Cards list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('savedCards')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cards = snapshot.data?.docs ?? [];

                    if (cards.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved cards',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a card to speed up checkout',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddCardDialog(context);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index].data() as Map<String, dynamic>;
                        final cardId = cards[index].id;
                        final lastFour = card['lastFour'] ?? '****';
                        final cardType = card['cardType'] ?? 'Card';
                        final holderName = card['holderName'] ?? '';
                        final expiry = card['expiry'] ?? '';
                        final isDefault = card['isDefault'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDefault
                                ? BorderSide(color: Colors.green.shade400, width: 2)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 50,
                              height: 35,
                              decoration: BoxDecoration(
                                color: _getCardColor(cardType),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Icon(
                                  _getCardIcon(cardType),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '$cardType •••• $lastFour',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              holderName.isNotEmpty
                                  ? '$holderName • Exp: $expiry'
                                  : 'Exp: $expiry',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'default') {
                                  _setDefaultCard(user.uid, cardId, cards);
                                } else if (value == 'delete') {
                                  _confirmDeleteCard(context, user.uid, cardId, lastFour);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isDefault)
                                  const PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 20),
                                        SizedBox(width: 8),
                                        Text('Set as Default'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCardColor(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
      case 'american express':
        return const Color(0xFF006FCF);
      case 'discover':
        return const Color(0xFFFF6000);
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
      case 'mastercard':
      case 'amex':
      case 'american express':
      case 'discover':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  void _showAddCardDialog(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) return;

    final cardNumberController = TextEditingController();
    final holderNameController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nicknameController = TextEditingController();
    bool setAsDefault = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cardNumberController,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    prefixIcon: const Icon(Icons.credit_card),
                    hintText: '1234 5678 9012 3456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  onChanged: (value) {
                    // Auto-format with spaces
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    final formatted = digitsOnly.replaceAllMapped(
                      RegExp(r'.{4}'),
                      (match) => '${match.group(0)} ',
                    ).trim();
                    if (formatted != value) {
                      cardNumberController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderNameController,
                  decoration: InputDecoration(
                    labelText: 'Cardholder Name',
                    prefixIcon: const Icon(Icons.person),
                    hintText: 'JOHN DOE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryController,
                        decoration: InputDecoration(
                          labelText: 'Expiry',
                          hintText: 'MM/YY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onChanged: (value) {
                          // Auto-format MM/YY
                          final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                          String formatted = digitsOnly;
                          if (digitsOnly.length >= 2) {
                            formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
                          }
                          if (formatted != value) {
                            expiryController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cvvController,
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nicknameController,
                  decoration: InputDecoration(
                    labelText: 'Card Nickname (optional)',
                    prefixIcon: const Icon(Icons.label_outline),
                    hintText: 'e.g., Personal Visa, Work Card',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: setAsDefault,
                  onChanged: (value) {
                    setDialogState(() => setAsDefault = value ?? false);
                  },
                  title: const Text('Set as default payment method'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cardNumber = cardNumberController.text.replaceAll(' ', '');
                final holderName = holderNameController.text.trim();
                final expiry = expiryController.text.trim();
                final cvv = cvvController.text.trim();
                final nickname = nicknameController.text.trim();

                // Basic validation
                if (cardNumber.length < 13) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid card number')),
                  );
                  return;
                }
                if (expiry.length != 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid expiry date (MM/YY)')),
                  );
                  return;
                }
                if (cvv.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid CVV')),
                  );
                  return;
                }

                // Determine card type
                final cardType = _detectCardType(cardNumber);
                final lastFour = cardNumber.substring(cardNumber.length - 4);

                // If setting as default, unset other defaults first
                if (setAsDefault) {
                  final existingCards = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('savedCards')
                      .where('isDefault', isEqualTo: true)
                      .get();

                  for (final doc in existingCards.docs) {
                    await doc.reference.update({'isDefault': false});
                  }
                }

                // Save card (in production, use a payment processor - this is demo only)
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('savedCards')
                    .add({
                  'lastFour': lastFour,
                  'cardType': cardType,
                  'holderName': holderName,
                  'expiry': expiry,
                  'nickname': nickname.isNotEmpty ? nickname : '$cardType •••• $lastFour',
                  'isDefault': setAsDefault,
                  'createdAt': FieldValue.serverTimestamp(),
                  // NOTE: Never store full card number or CVV in production!
                  // Use Stripe, Square, or another payment processor
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$cardType •••• $lastFour added'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Reopen saved cards sheet
                  _showSavedCards(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Card'),
            ),
          ],
        ),
      ),
    );
  }

  String _detectCardType(String cardNumber) {
    final number = cardNumber.replaceAll(RegExp(r'\D'), '');
    
    if (number.startsWith('4')) {
      return 'Visa';
    } else if (number.startsWith('5') || 
               (int.tryParse(number.substring(0, 4)) ?? 0) >= 2221 &&
               (int.tryParse(number.substring(0, 4)) ?? 0) <= 2720) {
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

  Future<void> _setDefaultCard(String uid, String cardId, List<QueryDocumentSnapshot> allCards) async {
    // Unset all other defaults
    for (final doc in allCards) {
      if (doc.id != cardId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('savedCards')
            .doc(doc.id)
            .update({'isDefault': false});
      }
    }

    // Set this card as default
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedCards')
        .doc(cardId)
        .update({'isDefault': true});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default payment method updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDeleteCard(BuildContext context, String uid, String cardId, String lastFour) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Are you sure you want to remove the card ending in $lastFour?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedCards')
                  .doc(cardId)
                  .delete();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Card removed'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/* ===================================================== */
/* ================= SELLER DASHBOARD =================== */
/* ===================================================== */

class SellerDashboardPage extends StatefulWidget {
  final String? businessId;
  final FirestoreService firestoreService;
  final AuthService authService;

  const SellerDashboardPage({
    super.key,
    required this.businessId,
    required this.firestoreService,
    required this.authService,
  });

  @override
  State<SellerDashboardPage> createState() => _SellerDashboardPageState();
}

class _SellerDashboardPageState extends State<SellerDashboardPage> {
  bool isCollapsed = true;
  bool acceptingReservations = true;
  
  // Track which section is selected
  String selectedSection = 'profile';

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final descriptionController = TextEditingController();

  final List<String> weekdayOrder = const [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];

  Map<String, bool> daysOpen = {};
  Map<String, Map<String, TimeOfDay?>> businessHours = {};

  @override
  void initState() {
    super.initState();

    for (final day in weekdayOrder) {
      daysOpen[day] = true;
      businessHours[day] = {
        "open": const TimeOfDay(hour: 9, minute: 0),
        "close": const TimeOfDay(hour: 18, minute: 0),
      };
    }

    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    if (widget.businessId == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(widget.businessId)
        .get();

    final data = doc.data();
    if (data == null) return;

    setState(() {
      nameController.text = data['name'] ?? '';
      addressController.text = data['address'] ?? '';
      descriptionController.text = data['description'] ?? '';
      acceptingReservations = data['acceptingReservations'] ?? true;

      final hours = data['hours'] as Map<String, dynamic>?;

      if (hours != null) {
        for (final day in weekdayOrder) {
          final d = hours[day];
          if (d == null) continue;

          daysOpen[day] = d['isOpen'] ?? true;

          businessHours[day] = {
            "open": _parseTime(d['open']),
            "close": _parseTime(d['close']),
          };
        }
      }
    });
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(":");
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String? _formatTime(TimeOfDay? t) {
    if (t == null) return null;
    return "${t.hour}:${t.minute}";
  }

  Future<void> _saveProfile() async {
    final Map<String, dynamic> hoursPayload = {};

    for (final day in weekdayOrder) {
      hoursPayload[day] = {
        "isOpen": daysOpen[day] ?? true,
        "open": _formatTime(businessHours[day]?["open"]),
        "close": _formatTime(businessHours[day]?["close"]),
      };
    }

    await widget.firestoreService.createOrUpdateBusinessProfile(
      businessId: widget.businessId,
      name: nameController.text,
      address: addressController.text,
      description: descriptionController.text,
      hours: hoursPayload,
      acceptingReservations: acceptingReservations,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile saved")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCollapsed ? 70 : 220,
            color: Colors.green[100],
            child: Column(
              children: [
                const SizedBox(height: 40),
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () =>
                      setState(() => isCollapsed = !isCollapsed),
                ),
                const SizedBox(height: 20),
                sidebarItem(
                  Icons.store,
                  "Profile",
                  isSelected: selectedSection == 'profile',
                  onTap: () => setState(() => selectedSection = 'profile'),
                ),
                sidebarItem(
                  Icons.inventory,
                  "Products",
                  isSelected: selectedSection == 'products',
                  onTap: () => setState(() => selectedSection = 'products'),
                ),
                sidebarItem(
                  Icons.receipt,
                  "Orders",
                  isSelected: selectedSection == 'orders',
                  onTap: () => setState(() => selectedSection = 'orders'),
                ),
                sidebarItem(
                  Icons.rate_review,
                  "Reviews",
                  isSelected: selectedSection == 'reviews',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerReviewsPage(
                          businessId: widget.businessId ?? '',
                        ),
                      ),
                    );
                  },
                ),
                sidebarItem(
                  Icons.history,
                  "My Purchases",
                  isSelected: selectedSection == 'purchases',
                  onTap: () => setState(() => selectedSection = 'purchases'),
                ),
                sidebarItem(
                  Icons.settings,
                  "Settings",
                  isSelected: selectedSection == 'settings',
                  onTap: () => setState(() => selectedSection = 'settings'),
                ),
                const Spacer(),
                sidebarItem(
                  Icons.logout,
                  "Logout",
                  isLogout: true,
                  onTap: () async {
                    await widget.authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AuthWrapper()),
                        (route) => false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
      //bottomNavigationBar: const AppBottomNavBar(currentIndex: -1),
    );
  }

  Widget _buildMainContent() {
    switch (selectedSection) {
      case 'products':
        return _buildProductsSection();
      case 'orders':
        return _buildOrdersSection();
      case 'purchases':
        return _buildPurchasesSection();
      case 'settings':
        return _buildSettingsSection();
      case 'profile':
      default:
        return _buildProfileSection();
    }
  }

  // PROFILE SECTION
  Widget _buildProfileSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Business Profile",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Business Name"),
          ),
          TextField(
            controller: addressController,
            decoration: const InputDecoration(labelText: "Address"),
          ),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: "Description"),
          ),

          const SizedBox(height: 20),

          SwitchListTile(
            title: const Text("Accepting Reservations"),
            value: acceptingReservations,
            onChanged: (v) => setState(() => acceptingReservations = v),
          ),

          const SizedBox(height: 20),

          const Text(
            "Business Hours",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          ...weekdayOrder.map((day) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Use compact layout for narrow screens
                  final isCompact = constraints.maxWidth < 350;
                  
                  if (isCompact) {
                    // Stacked layout for phones
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: daysOpen[day] ?? true,
                                  onChanged: (v) {
                                    setState(() {
                                      daysOpen[day] = v ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: (daysOpen[day] ?? true) 
                                        ? Colors.black 
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              if (!(daysOpen[day] ?? true))
                                Text(
                                  'Closed',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          if (daysOpen[day] ?? true)
                            Padding(
                              padding: const EdgeInsets.only(left: 32, top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: businessHours[day]!["open"] ??
                                              const TimeOfDay(hour: 9, minute: 0),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            businessHours[day]!["open"] = picked;
                                          });
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      child: Text(
                                        businessHours[day]!["open"]?.format(context) ?? "Open",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      "to",
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final picked = await showTimePicker(
                                          context: context,
                                          initialTime: businessHours[day]!["close"] ??
                                              const TimeOfDay(hour: 18, minute: 0),
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            businessHours[day]!["close"] = picked;
                                          });
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      child: Text(
                                        businessHours[day]!["close"]?.format(context) ?? "Close",
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  } else {
                    // Row layout for tablets/larger screens
                    return Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: daysOpen[day] ?? true,
                            onChanged: (v) {
                              setState(() {
                                daysOpen[day] = v ?? false;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(width: 90, child: Text(day)),
                        if (daysOpen[day] ?? true) ...[
                          Expanded(
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: businessHours[day]!["open"] ??
                                          const TimeOfDay(hour: 9, minute: 0),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        businessHours[day]!["open"] = picked;
                                      });
                                    }
                                  },
                                  child: Text(
                                    businessHours[day]!["open"]?.format(context) ?? "Open",
                                  ),
                                ),
                                const Text(" - "),
                                TextButton(
                                  onPressed: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: businessHours[day]!["close"] ??
                                          const TimeOfDay(hour: 18, minute: 0),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        businessHours[day]!["close"] = picked;
                                      });
                                    }
                                  },
                                  child: Text(
                                    businessHours[day]!["close"]?.format(context) ?? "Close",
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Expanded(
                            child: Text(
                              'Closed',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                      ],
                    );
                  }
                },
              ),
            );
          }),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _saveProfile,
            child: const Text("Save Profile"),
          ),
        ],
      ),
    );
  }

  // PRODUCTS SECTION
  Widget _buildProductsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.firestoreService.getProducts(businessId: widget.businessId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Products",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditItemPage(
                            businessId: widget.businessId ?? '',
                            product: const {},
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add Product"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (products.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        "No products yet",
                        style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap 'Add Product' to create your first listing",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: products.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        data['productId'] = doc.id;

                        return _buildResponsiveProductCard(
                          context: context,
                          data: data,
                          docId: doc.id,
                          maxWidth: constraints.maxWidth,
                        );
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponsiveProductCard({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String docId,
    required double maxWidth,
  }) {
    // Compact layout for narrow screens (< 300px)
    final isCompact = maxWidth < 300;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: isCompact
            ? _buildCompactProductCard(context, data, docId)
            : _buildWideProductCard(context, data, docId),
      ),
    );
  }

  Widget _buildCompactProductCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                ProductIcons.fromKey(data['iconKey']),
                size: 24,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data["name"] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "\$${data["price"]} / ${data["unit"] ?? 'ea'}",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Stock: ${data["quantity"]}",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditItemPage(
                            productId: docId,
                            businessId: widget.businessId ?? '',
                            product: data,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text("Edit", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                SizedBox(
                  height: 32,
                  child: TextButton.icon(
                    onPressed: () => _confirmDeleteProduct(context, data, docId),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text("Delete", style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWideProductCard(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            ProductIcons.fromKey(data['iconKey']),
            size: 30,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data["name"] ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                "\$${data["price"]} / ${data["unit"] ?? 'ea'} • Stock: ${data["quantity"]}",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditItemPage(
                  productId: docId,
                  businessId: widget.businessId ?? '',
                  product: data,
                ),
              ),
            );
          },
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteProduct(context, data, docId),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _confirmDeleteProduct(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product"),
        content: Text("Are you sure you want to delete '${data['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('products').doc(docId).delete();
    }
  }

  // ORDERS SECTION (placeholder)
  Widget _buildOrdersSection() {
    final user = widget.authService.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
        final businessId = userData?['businessId'] ?? '';

        if (businessId.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  "No Business Found",
                  style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  "Set up your business profile to receive orders",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sellerOrders')
              .doc(businessId)
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      "No Orders Yet",
                      style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Orders from customers will appear here",
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            final orders = snapshot.data!.docs;
            
            // Separate pending and completed orders
            final pendingOrders = orders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] == 'pending';
            }).toList();
            
            final completedOrders = orders.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['status'] != 'pending';
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        "Order Management",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: pendingOrders.isNotEmpty 
                              ? Colors.orange.shade100 
                              : Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              pendingOrders.isNotEmpty 
                                  ? Icons.pending_actions 
                                  : Icons.check_circle,
                              size: 16,
                              color: pendingOrders.isNotEmpty 
                                  ? Colors.orange.shade700 
                                  : Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${pendingOrders.length} pending',
                              style: TextStyle(
                                color: pendingOrders.isNotEmpty 
                                    ? Colors.orange.shade700 
                                    : Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pending Orders Section
                  if (pendingOrders.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pending Orders (${pendingOrders.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...pendingOrders.map((doc) => _buildOrderCard(doc, businessId, isPending: true)),
                    const SizedBox(height: 24),
                  ],

                  // Completed Orders Section
                  if (completedOrders.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.grey.shade600, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Completed Orders (${completedOrders.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...completedOrders.map((doc) => _buildOrderCard(doc, businessId, isPending: false)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc, String businessId, {required bool isPending}) {
    final data = doc.data() as Map<String, dynamic>;
    final items = (data['items'] as List<dynamic>?) ?? [];
    final subtotal = (data['subtotal'] ?? 0).toDouble();
    final buyerName = data['buyerName'] ?? 'Customer';
    final buyerEmail = data['buyerEmail'] ?? '';
    final status = data['status'] ?? 'pending';
    final createdAt = data['createdAt'] as Timestamp?;
    final date = createdAt?.toDate();
    final deliveryAddress = data['deliveryAddress'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending 
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isPending ? Colors.orange.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPending ? Icons.receipt_long : Icons.check_circle,
            color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                buyerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '\$${subtotal.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              date != null
                  ? '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                  : 'Date unknown',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(status),
                ),
              ),
            ),
          ],
        ),
        children: [
          const Divider(),
          
          // Customer info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        buyerEmail,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
                if (deliveryAddress.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deliveryAddress,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items
          const Text(
            'Order Items',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...items.map((item) {
            final itemData = item as Map<String, dynamic>;
            final name = itemData['name'] ?? '';
            final price = (itemData['price'] ?? 0).toDouble();
            final quantity = itemData['quantity'] ?? 1;
            final pickupTime = itemData['pickupTime'] as Timestamp?;
            final pickupDate = pickupTime?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        'x$quantity',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${(price * quantity).toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (pickupDate != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          'Pickup: ${pickupDate.month}/${pickupDate.day} at ${pickupDate.hour}:${pickupDate.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),

          // Action buttons
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateOrderStatus(businessId, doc.id, 'cancelled'),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(businessId, doc.id, 'ready'),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Mark Ready for Pickup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'ready') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _updateOrderStatus(businessId, doc.id, 'completed'),
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Mark as Picked Up / Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'ready':
        return Colors.blue.shade700;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Future<void> _updateOrderStatus(String businessId, String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('sellerOrders')
          .doc(businessId)
          .collection('orders')
          .doc(orderId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as ${newStatus.toUpperCase()}'),
            backgroundColor: _getStatusColor(newStatus),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // SETTINGS SECTION
  Widget _buildSettingsSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Settings",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Notifications"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showNotificationsDialog(context),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.payment),
              title: const Text("Payment Methods"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPaymentMethodsDialog(context),
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.help),
              title: const Text("Help & Support"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showHelpSupportDialog(context),
            ),
          ),

          const SizedBox(height: 30),

          Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Log Out", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await widget.authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============== SETTINGS DIALOGS ==============

  void _showAccountSettingsDialog(BuildContext context) {
    final user = widget.authService.currentUser;
    if (user == null) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get()
        .then((doc) {
      if (doc.exists) {
        nameController.text = doc.data()?['name'] ?? '';
        phoneController.text = doc.data()?['phone'] ?? '';
      }
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: user.email),
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showChangePasswordDialog(context);
                },
                icon: const Icon(Icons.lock),
                label: const Text('Change Password'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showDeleteAccountDialog(context);
                },
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account updated successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwords do not match')),
                        );
                        return;
                      }

                      if (newPasswordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password must be at least 6 characters')),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && user.email != null) {
                          final credential = EmailAuthProvider.credential(
                            email: user.email!,
                            password: currentPasswordController.text,
                          );
                          await user.reauthenticateWithCredential(credential);
                          await user.updatePassword(newPasswordController.text);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password changed successfully')),
                            );
                          }
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Change Password', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Delete Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete your account? This action cannot be undone.',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Enter your password to confirm',
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() => isLoading = true);

                      try {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && user.email != null) {
                          final credential = EmailAuthProvider.credential(
                            email: user.email!,
                            password: passwordController.text,
                          );
                          await user.reauthenticateWithCredential(credential);

                          // Delete user data from Firestore
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .delete();

                          // Delete the auth account
                          await user.delete();

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete Account', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    final user = widget.authService.currentUser;
    if (user == null) return;

    bool orderUpdates = true;
    bool newOrders = true;
    bool reviews = true;
    bool emailNotifications = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Notification Preferences'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('New Customer Orders'),
                  subtitle: const Text('When customers place orders'),
                  value: newOrders,
                  onChanged: (value) => setState(() => newOrders = value),
                  activeColor: Colors.green,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Your Purchase Updates'),
                  subtitle: const Text('Status of your own orders'),
                  value: orderUpdates,
                  onChanged: (value) => setState(() => orderUpdates = value),
                  activeColor: Colors.green,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('New Reviews'),
                  subtitle: const Text('When customers leave reviews'),
                  value: reviews,
                  onChanged: (value) => setState(() => reviews = value),
                  activeColor: Colors.green,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  subtitle: const Text('Receive notifications via email'),
                  value: emailNotifications,
                  onChanged: (value) => setState(() => emailNotifications = value),
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({
                  'notificationPrefs': {
                    'orderUpdates': orderUpdates,
                    'newOrders': newOrders,
                    'reviews': reviews,
                    'emailNotifications': emailNotifications,
                  },
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification preferences saved')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodsDialog(BuildContext context) {
    final user = widget.authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Methods',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showAddCardDialogSeller(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Card'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Cards list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('savedCards')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cards = snapshot.data?.docs ?? [];

                    if (cards.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved cards',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add a card to speed up checkout',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _showAddCardDialogSeller(context);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Card'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index].data() as Map<String, dynamic>;
                        final cardId = cards[index].id;
                        final lastFour = card['lastFour'] ?? '****';
                        final cardType = card['cardType'] ?? 'Card';
                        final holderName = card['holderName'] ?? '';
                        final expiry = card['expiry'] ?? '';
                        final isDefault = card['isDefault'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isDefault
                                ? BorderSide(color: Colors.green.shade400, width: 2)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: Container(
                              width: 50,
                              height: 35,
                              decoration: BoxDecoration(
                                color: _getCardColorSeller(cardType),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.credit_card,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '$cardType •••• $lastFour',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              holderName.isNotEmpty
                                  ? '$holderName • Exp: $expiry'
                                  : 'Exp: $expiry',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'default') {
                                  _setDefaultCardSeller(user.uid, cardId, cards);
                                } else if (value == 'delete') {
                                  _confirmDeleteCardSeller(context, user.uid, cardId, lastFour);
                                }
                              },
                              itemBuilder: (context) => [
                                if (!isDefault)
                                  const PopupMenuItem(
                                    value: 'default',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 20),
                                        SizedBox(width: 8),
                                        Text('Set as Default'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCardColorSeller(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
      case 'american express':
        return const Color(0xFF006FCF);
      case 'discover':
        return const Color(0xFFFF6000);
      default:
        return Colors.grey.shade700;
    }
  }

  String _detectCardTypeSeller(String cardNumber) {
    final number = cardNumber.replaceAll(RegExp(r'\D'), '');
    
    if (number.startsWith('4')) {
      return 'Visa';
    } else if (number.startsWith('5') || 
               (int.tryParse(number.substring(0, 4)) ?? 0) >= 2221 &&
               (int.tryParse(number.substring(0, 4)) ?? 0) <= 2720) {
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

  void _showAddCardDialogSeller(BuildContext context) {
    final user = widget.authService.currentUser;
    if (user == null) return;

    final cardNumberController = TextEditingController();
    final holderNameController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final nicknameController = TextEditingController();
    bool setAsDefault = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Payment Method'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: cardNumberController,
                  decoration: InputDecoration(
                    labelText: 'Card Number',
                    prefixIcon: const Icon(Icons.credit_card),
                    hintText: '1234 5678 9012 3456',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  onChanged: (value) {
                    // Auto-format with spaces
                    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                    final formatted = digitsOnly.replaceAllMapped(
                      RegExp(r'.{4}'),
                      (match) => '${match.group(0)} ',
                    ).trim();
                    if (formatted != value) {
                      cardNumberController.value = TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: holderNameController,
                  decoration: InputDecoration(
                    labelText: 'Cardholder Name',
                    prefixIcon: const Icon(Icons.person),
                    hintText: 'JOHN DOE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: expiryController,
                        decoration: InputDecoration(
                          labelText: 'Expiry',
                          hintText: 'MM/YY',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        onChanged: (value) {
                          // Auto-format MM/YY
                          final digitsOnly = value.replaceAll(RegExp(r'\D'), '');
                          String formatted = digitsOnly;
                          if (digitsOnly.length >= 2) {
                            formatted = '${digitsOnly.substring(0, 2)}/${digitsOnly.substring(2)}';
                          }
                          if (formatted != value) {
                            expiryController.value = TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: cvvController,
                        decoration: InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nicknameController,
                  decoration: InputDecoration(
                    labelText: 'Card Nickname (optional)',
                    prefixIcon: const Icon(Icons.label_outline),
                    hintText: 'e.g., Business Card, Personal',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: setAsDefault,
                  onChanged: (value) {
                    setDialogState(() => setAsDefault = value ?? false);
                  },
                  title: const Text('Set as default payment method'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cardNumber = cardNumberController.text.replaceAll(' ', '');
                final holderName = holderNameController.text.trim();
                final expiry = expiryController.text.trim();
                final cvv = cvvController.text.trim();
                final nickname = nicknameController.text.trim();

                // Basic validation
                if (cardNumber.length < 13) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid card number')),
                  );
                  return;
                }
                if (expiry.length != 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid expiry date (MM/YY)')),
                  );
                  return;
                }
                if (cvv.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid CVV')),
                  );
                  return;
                }

                // Determine card type
                final cardType = _detectCardTypeSeller(cardNumber);
                final lastFour = cardNumber.substring(cardNumber.length - 4);

                // If setting as default, unset other defaults first
                if (setAsDefault) {
                  final existingCards = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('savedCards')
                      .where('isDefault', isEqualTo: true)
                      .get();

                  for (final doc in existingCards.docs) {
                    await doc.reference.update({'isDefault': false});
                  }
                }

                // Save card
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('savedCards')
                    .add({
                  'lastFour': lastFour,
                  'cardType': cardType,
                  'holderName': holderName,
                  'expiry': expiry,
                  'nickname': nickname.isNotEmpty ? nickname : '$cardType •••• $lastFour',
                  'isDefault': setAsDefault,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$cardType •••• $lastFour added'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Reopen payment methods sheet
                  _showPaymentMethodsDialog(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add Card'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefaultCardSeller(String uid, String cardId, List<QueryDocumentSnapshot> allCards) async {
    // Unset all other defaults
    for (final doc in allCards) {
      if (doc.id != cardId) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('savedCards')
            .doc(doc.id)
            .update({'isDefault': false});
      }
    }

    // Set this card as default
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedCards')
        .doc(cardId)
        .update({'isDefault': true});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default payment method updated'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDeleteCardSeller(BuildContext context, String uid, String cardId, String lastFour) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Are you sure you want to remove the card ending in $lastFour?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedCards')
                  .doc(cardId)
                  .delete();

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Card removed')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Seller FAQ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              _buildFaqItem(
                'How do I add products?',
                'Go to Products section and tap "Add Product" to create a new listing.',
              ),
              _buildFaqItem(
                'How do I update my business hours?',
                'Go to Profile section and edit your business hours, then save.',
              ),
              _buildFaqItem(
                'How do I view my reviews?',
                'Click on "Reviews" in the sidebar to see all customer reviews.',
              ),
              _buildFaqItem(
                'Can I also buy from other sellers?',
                'Yes! Browse the Shop and Discover pages to find products from other sellers.',
              ),

              const Divider(height: 32),

              const Text(
                'Contact Us',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.email, color: Colors.green),
                title: const Text('Email Support'),
                subtitle: const Text('sellers@foodoasis.app'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              ListTile(
                leading: const Icon(Icons.phone, color: Colors.green),
                title: const Text('Phone Support'),
                subtitle: const Text('1-800-FOOD-OASIS'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),

              const Divider(height: 32),

              const Text(
                'About Food Oasis',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Food Oasis connects local buyers with healthy food sellers in their community.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontSize: 14)),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Text(
          answer,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  // Cache for business names in seller purchase history
  Map<String, String> _sellerPurchaseHistoryBusinessNames = {};

  Future<String> _getBusinessNameForSellerHistory(String businessId) async {
    if (_sellerPurchaseHistoryBusinessNames.containsKey(businessId)) {
      return _sellerPurchaseHistoryBusinessNames[businessId]!;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();

      if (doc.exists) {
        final name = doc.data()?['name'] ?? 'Unknown Seller';
        _sellerPurchaseHistoryBusinessNames[businessId] = name;
        return name;
      }
    } catch (e) {
      // Handle error
    }

    _sellerPurchaseHistoryBusinessNames[businessId] = 'Unknown Seller';
    return 'Unknown Seller';
  }

  // Group items by businessId for seller purchases
  Map<String, List<Map<String, dynamic>>> _groupItemsByVendorSeller(List<dynamic> items) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final item in items) {
      final itemData = item as Map<String, dynamic>;
      final businessId = itemData['businessId'] ?? 'unknown';
      if (!grouped.containsKey(businessId)) {
        grouped[businessId] = [];
      }
      grouped[businessId]!.add(itemData);
    }
    
    return grouped;
  }

  Widget _buildPurchasesSection() {
    final user = widget.authService.currentUser;
    if (user == null) {
      return const Center(child: Text('Please log in to view purchase history'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Purchase History',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data!.docs;

              if (orders.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No orders yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your purchase history will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: orders.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final items = (data['items'] as List<dynamic>?) ?? [];
                  final total = (data['total'] ?? 0).toDouble();
                  final status = data['status'] ?? 'completed';
                  final createdAt = data['createdAt'] as Timestamp?;
                  final date = createdAt?.toDate();

                  // Group items by vendor
                  final groupedItems = _groupItemsByVendorSeller(items);
                  final vendorCount = groupedItems.keys.length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
                      ),
                      title: Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              Text(
                                date != null
                                    ? '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                                    : 'Date unknown',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              if (vendorCount > 1)
                                Text(
                                  '• $vendorCount sellers',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'completed' ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'completed' ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        const Divider(),
                        const SizedBox(height: 8),
                        
                        // Grouped by vendor
                        ...groupedItems.entries.map((entry) {
                          final businessId = entry.key;
                          final vendorItems = entry.value;
                          final vendorSubtotal = vendorItems.fold<double>(
                            0,
                            (sum, item) => sum + ((item['price'] ?? 0) * (item['quantity'] ?? 1)),
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Vendor header
                                FutureBuilder<String>(
                                  future: _getBusinessNameForSellerHistory(businessId),
                                  builder: (context, snapshot) {
                                    final businessName = snapshot.data ?? 'Loading...';
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.storefront, size: 16, color: Colors.green.shade700),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              businessName,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '\$${vendorSubtotal.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                // Vendor items
                                ...vendorItems.map((itemData) {
                                  // Format pickup time if available
                                  String? pickupTimeStr;
                                  final pickupTime = itemData['pickupTime'];
                                  if (pickupTime != null) {
                                    DateTime dt;
                                    if (pickupTime is Timestamp) {
                                      dt = pickupTime.toDate();
                                    } else {
                                      dt = pickupTime as DateTime;
                                    }
                                    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
                                    final minute = dt.minute.toString().padLeft(2, '0');
                                    final period = dt.hour >= 12 ? 'PM' : 'AM';
                                    pickupTimeStr = '${dt.month}/${dt.day} at $hour:$minute $period';
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(Icons.fastfood, size: 18, color: Colors.grey),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                itemData['name'] ?? 'Unknown item',
                                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                'Qty: ${itemData['quantity']} × \$${(itemData['price'] ?? 0).toStringAsFixed(2)}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                              if (pickupTimeStr != null)
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule, size: 12, color: Colors.blue.shade600),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                      child: Text(
                                                        'Pickup: $pickupTimeStr',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.blue.shade700,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '\$${((itemData['price'] ?? 0) * (itemData['quantity'] ?? 1)).toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        }).toList(),

                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order Total', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '\$${total.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }  

  Widget sidebarItem(
    IconData icon,
    String label, {
    bool isLogout = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      color: isSelected ? Colors.green.shade200 : null,
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.red : (isSelected ? Colors.green.shade800 : Colors.black),
        ),
        title: isCollapsed
            ? null
            : Text(
                label,
                style: TextStyle(
                  color: isLogout ? Colors.red : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
        onTap: onTap,
      ),
    );
  }
}