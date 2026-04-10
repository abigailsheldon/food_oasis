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
                    Row(
                      children: [
                        Text(
                          date != null
                              ? '${date.month}/${date.day}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}'
                              : 'Date unknown',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (vendorCount > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• $vendorCount sellers',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          ),
                        ],
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
                                              Text(
                                                'Pickup: $pickupTimeStr',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue.shade700,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            "Orders Coming Soon",
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            "Order management will be available in a future update",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Methods'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('savedCards')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final cards = snapshot.data!.docs;

              if (cards.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card_off, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text('No saved payment methods'),
                    const SizedBox(height: 8),
                    const Text(
                      'Cards saved during checkout will appear here',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...cards.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.credit_card, color: Colors.green.shade700),
                        title: Text(data['nickname'] ?? 'Saved Card'),
                        subtitle: Text('•••• ${data['lastFour']} | Exp: ${data['expiry']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove Card'),
                                content: const Text('Are you sure you want to remove this card?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Remove', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('savedCards')
                                  .doc(doc.id)
                                  .delete();
                            }
                          },
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                  Text(
                    'To add a new card, save it during checkout',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
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
                        ...items.map((item) {
                          final itemData = item as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.fastfood, size: 20, color: Colors.grey),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              itemData['name'] ?? 'Unknown item',
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              'Qty: ${itemData['quantity']} × \$${(itemData['price'] ?? 0).toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${((itemData['price'] ?? 0) * (itemData['quantity'] ?? 1)).toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
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