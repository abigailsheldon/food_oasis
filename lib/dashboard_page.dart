import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  bool isCollapsed = false;

  final nameController = TextEditingController(text: "Fresh Farm Market");
  final addressController = TextEditingController(text: "123 Peachtree St, Atlanta");
  final hoursController = TextEditingController(text: "9 AM - 6 PM");
  final descriptionController = TextEditingController(text: "Local organic fruits and vegetables.");

  // FAKE PRODUCT DATA
  final Map<String, List<String>> productCategories = {
    "Fruits": ["Apples", "Strawberries", "Peaches"],
    "Vegetables": ["Carrots", "Spinach", "Tomatoes"],
    "Dairy": ["Milk", "Eggs"]
  };

  @override
  Widget build(BuildContext context) {

    double sidebarWidth = isCollapsed ? 70 : 220;

    return Scaffold(
      body: Row(
        children: [

          // SIDEBAR
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
                    // navigate to orders page later
                  },
                ),
              ],
            ),
          ),

          // MAIN CONTENT
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    "Business Profile",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 25),

                  profileField("Business Name", nameController),
                  profileField("Address", addressController),
                  profileField("Hours", hoursController),
                  profileField("Description", descriptionController),

                  const SizedBox(height: 40),

                  const Text(
                    "Products",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  ...productCategories.entries.map((category) {

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Text(
                          category.key,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          children: category.value.map((product) {

                            return Chip(
                              label: Text(product),
                            );

                          }).toList(),
                        ),

                        const SizedBox(height: 25)
                      ],
                    );

                  }).toList(),
                ],
              ),
            ),
          )
        ],
      ),
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

  Widget sidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: isCollapsed ? null : Text(label),
      onTap: onTap,
    );
  }
}