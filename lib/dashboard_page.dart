import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_item_page.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'auth/seller_signup_page.dart';

import 'geocode_businesses_page.dart';


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
          title: const Text('Dashboard'),
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
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SellerOnboardingPage(),
                ),
              );
            },
            child: const Text("Sign Up as a Seller"),
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
                sidebarItem(Icons.receipt, "Orders"),
                sidebarItem(Icons.discount, "Promotions"),
                sidebarItem(Icons.rate_review, "Reviews"),
                sidebarItem(Icons.settings, "Settings"),
                const Spacer(),
                sidebarItem(Icons.logout, "Logout", isLogout: true),
                const SizedBox(height: 20),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.firestoreService
                  .getProducts(businessId: widget.businessId),
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
                      const Text(
                        "Business Profile",
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),

                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                            labelText: "Business Name"),
                      ),
                      TextField(
                        controller: addressController,
                        decoration:
                            const InputDecoration(labelText: "Address"),
                      ),
                      TextField(
                        controller: descriptionController,
                        decoration:
                            const InputDecoration(labelText: "Description"),
                      ),

                      const SizedBox(height: 20),

                      SwitchListTile(
                        title: const Text("Accepting Reservations"),
                        value: acceptingReservations,
                        onChanged: (v) =>
                            setState(() => acceptingReservations = v),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Business Hours",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
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
                                  businessHours[day]!["open"]?.format(
                                          context) ??
                                      "Open",
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
                                  businessHours[day]!["close"]?.format(
                                          context) ??
                                      "Close",
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

                      // FOR TESTING GOOGLE MAPS API
                      /*
                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GeocodeBusinessesPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text("Admin: Geocode Businesses"),
                      ),
                      */

                      const SizedBox(height: 30),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Products",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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

                      const SizedBox(height: 10),

                      if (products.isEmpty)
                        const Text("No products yet. Tap 'Add Product' to create one!")
                      else
                        Column(
                          children: products.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['productId'] = doc.id;

                            return Card(
                              child: ListTile(
                                title: Text(data["name"] ?? ""),
                                subtitle: Text(
                                    "Price: \$${data["price"]} | Stock: ${data["quantity"]}"),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget sidebarItem(IconData icon, String label, {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.black),
      title: isCollapsed ? null : Text(label),
      onTap: () async {
        if (isLogout) {
          await widget.authService.signOut();
        }
      },
    );
  }
}