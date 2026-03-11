import 'package:flutter/material.dart';
import 'edit_item_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isCollapsed = true;

  final nameController = TextEditingController(text: "Fresh Farm Market");
  final addressController = TextEditingController(text: "123 Peachtree St, Atlanta, GA");
  final hoursController = TextEditingController(text: "9 AM - 6 PM");
  final descriptionController = TextEditingController(text: "Local organic fruits and vegetables.");

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
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    setState(() {
                      isCollapsed = !isCollapsed;
                    });
                  },
                ),

                const SizedBox(height: 20),

                sidebarItem(
                  icon: Icons.receipt,
                  label: "Orders",
                  onTap: () {
                    // Will navigate to orders page later
                  },
                ),
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
                    "Business Profile",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),

                  profileField("Business Name", nameController),
                  profileField("Address", addressController),
                  profileField("Hours", hoursController),
                  profileField("Description", descriptionController),

                  const SizedBox(height: 40),

                  const Text(
                    "Products",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  ...productCategories.entries.map((category) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          category.key,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
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

  Widget sidebarItem({required IconData icon, required String label, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
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
}