import 'package:flutter/material.dart';
import 'edit_item_page.dart';
import 'services/auth_service.dart';


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isCollapsed = true;

  final AuthService _authService = AuthService();

  final nameController = TextEditingController(text: "Fresh Farm Market");
  final addressController = TextEditingController(text: "123 Peachtree St, Atlanta, GA");
  final descriptionController = TextEditingController(text: "Local organic fruits and vegetables.");

  Map<String, Map<String, TimeOfDay?>> businessHours = {
    "Monday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Tuesday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Wednesday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Thursday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Friday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Saturday": {"open": TimeOfDay(hour: 9, minute: 0), "close": TimeOfDay(hour: 18, minute: 0)},
    "Sunday": {"open": null, "close": null},
  };

  Map<String, bool> daysOpen = {
    "Monday": true,
    "Tuesday": true,
    "Wednesday": true,
    "Thursday": true,
    "Friday": true,
    "Saturday": true,
    "Sunday": false,
  };

  bool acceptingReservations = true;

  Map<String, List<Map<String, dynamic>>> productCategories = {
    "Fruits": [
      {"name": "Apples", "price": 2.5, "stock": 10},
      {"name": "Strawberries", "price": 3.0, "stock": 15},
    ],
    "Vegetables": [
      {"name": "Carrots", "price": 1.5, "stock": 20},
      {"name": "Spinach", "price": 2.0, "stock": 12},
    ],
    "Dairy": [
      {"name": "Milk", "price": 3.0, "stock": 8},
      {"name": "Eggs", "price": 4.0, "stock": 30},
    ]
  };

  @override
  Widget build(BuildContext context) {
    double sidebarWidth = isCollapsed ? 70 : 220;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            color: Colors.green[100],
            child: Column(
              children: [
                const SizedBox(height: 40),
                IconButton(
                  icon: const Icon(Icons.menu), color: Colors.black,
                  onPressed: () {
                    setState(() {
                      isCollapsed = !isCollapsed;
                    });
                  },
                ),
                const SizedBox(height: 20),
                sidebarItem(
                  icon: Icons.receipt, iconColor: Colors.black,
                  label: "Orders",
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                sidebarItem(
                  icon: Icons.discount, iconColor: Colors.black,
                  label: "Promotions",
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                sidebarItem(
                  icon: Icons.rate_review, iconColor: Colors.black,
                  label: "Reviews",
                  onTap: () {},
                ),
                const SizedBox(height: 20),
                sidebarItem(
                  icon: Icons.settings, iconColor: Colors.black,
                  label: "Settings",
                  onTap: () {},
                ),
                const Spacer(),  // Pushes logout to bottom
                sidebarItem(
                  icon: Icons.logout,
                  iconColor: Colors.red,
                  label: "Logout",
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Business Details",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),

                  profileField("Business Name", nameController),
                  profileField("Address", addressController),
                  profileField("Description", descriptionController),
                  const SizedBox(height: 20),

                  const Text("Business Hours", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),

                  ...daysOpen.keys.map((day) {
                    return Row(
                      children: [
                        Checkbox(
                          value: daysOpen[day],
                          onChanged: (val) {
                            setState(() {
                              daysOpen[day] = val ?? false;
                              if (!daysOpen[day]!) {
                                businessHours[day]!["open"] = null;
                                businessHours[day]!["close"] = null;
                              } else {
                                businessHours[day]!["open"] ??= TimeOfDay(hour: 9, minute: 0);
                                businessHours[day]!["close"] ??= TimeOfDay(hour: 18, minute: 0);
                              }
                            });
                          },
                          checkColor: Colors.white,
                          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                            if (states.contains(MaterialState.selected)) {
                              return Colors.green[800]!;
                            }
                            return Colors.white;
                          }),
                          side: const BorderSide(
                            color: Colors.green,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: 5),
                        SizedBox(
                          width: 80,
                          child: Text(day),
                        ),
                        const SizedBox(width: 10),
                        if (daysOpen[day]!)
                          Row(
                            children: [
                              TextButton(
                                onPressed: () async {
                                  TimeOfDay initialOpen = businessHours[day]!["open"] ?? const TimeOfDay(hour: 9, minute: 0);
                                  TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialTime: initialOpen,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      businessHours[day]!["open"] = picked;
                                    });
                                  }
                                },
                                child: Text(
                                  (businessHours[day]!["open"] ?? const TimeOfDay(hour: 9, minute: 0)).format(context),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                              const Text(" - "),
                              TextButton(
                                onPressed: () async {
                                  TimeOfDay initialClose = businessHours[day]!["close"] ?? const TimeOfDay(hour: 18, minute: 0);
                                  TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialTime: initialClose,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      businessHours[day]!["close"] = picked;
                                    });
                                  }
                                },
                                child: Text(
                                  (businessHours[day]!["close"] ?? const TimeOfDay(hour: 18, minute: 0)).format(context),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  }).toList(),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Switch(
                        value: acceptingReservations,
                        onChanged: (val) {
                          setState(() {
                            acceptingReservations = val;
                          });
                        },
                        activeColor: Colors.white,
                        activeTrackColor: Colors.green[800],
                        inactiveThumbColor: Colors.green[800],
                        inactiveTrackColor: Colors.green[100],
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 6),
                      const Text("Accepting Reservations"),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Business details saved")),
                      );
                    },
                    child: const Text("Save Business Profile"),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    "Products",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  ...productCategories.entries.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.key, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        Column(
                          children: category.value.map((product) {
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              child: ListTile(
                                title: Text(product["name"]),
                                subtitle: Text("Price: \$${product["price"]} | Stock: ${product["stock"]}"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        editProduct(category.key, product);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () {
                                        deleteProduct(category.key, product);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 15),

                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            addProduct(category.key);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text("Add Product"),
                        ),

                        const SizedBox(height: 25),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sidebarItem({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: isCollapsed ? null : Text(label),
      onTap: onTap,
    );
  }

  Widget profileField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  void addProduct(String category) {
    setState(() {
      productCategories[category]!.add({"name": "New Product", "price": 0.0, "stock": 0});
    });
  }

  void editProduct(String category, Map<String, dynamic> product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditItemPage(
          category: category,
          product: product,
        ),
      ),
    );
  }

  void deleteProduct(String category, Map<String, dynamic> product) {
    setState(() {
      productCategories[category]!.remove(product);
    });
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
    }
  }

}