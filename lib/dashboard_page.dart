import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_item_page.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'auth/seller_signup_page.dart';
import 'seller_reviews_page.dart';
import 'app_bottom_nav.dart';


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
          title: const Text('My Account'),
          backgroundColor: Colors.green.shade50,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () async {
                await _authService.signOut();
              },
              tooltip: 'Logout',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Become a Seller Card
              Card(
                color: Colors.green.shade50,
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

              // Purchase History Section
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
            return Row(
              children: [
                Checkbox(
                  value: daysOpen[day] ?? true,
                  onChanged: (v) {
                    setState(() {
                      daysOpen[day] = v ?? false;
                    });
                  },
                ),
                SizedBox(width: 90, child: Text(day)),
                if (daysOpen[day] ?? true) ...[
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
              ],
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final products = snapshot.data!.docs;

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
                Column(
                  children: products.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['productId'] = doc.id;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.fastfood, color: Colors.green),
                        ),
                        title: Text(data["name"] ?? ""),
                        subtitle: Text(
                          "\$${data["price"]} / ${data["unit"] ?? 'ea'} • Stock: ${data["quantity"]}",
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditItemPage(
                                      productId: doc.id,
                                      businessId: widget.businessId ?? '',
                                      product: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Delete Product"),
                                    content: Text(
                                        "Are you sure you want to delete '${data['name']}'?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text("Delete",
                                            style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('products')
                                      .doc(doc.id)
                                      .delete();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
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
              leading: const Icon(Icons.person),
              title: const Text("Account Settings"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement account settings
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Notifications"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement notifications settings
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.payment),
              title: const Text("Payment Methods"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement payment settings
              },
            ),
          ),

          Card(
            child: ListTile(
              leading: const Icon(Icons.help),
              title: const Text("Help & Support"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: Implement help
              },
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