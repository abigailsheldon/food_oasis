import 'package:flutter/material.dart';

class EditItemPage extends StatefulWidget {
  final String category;
  final Map<String, dynamic> product;

  const EditItemPage({
    super.key,
    required this.category,
    required this.product,
  });

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late TextEditingController nameController;
  late TextEditingController priceController;
  late TextEditingController stockController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.product["name"]);
    priceController = TextEditingController(text: widget.product["price"].toString());
    stockController = TextEditingController(text: widget.product["stock"].toString());
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Item")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Product Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Stock",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                // Save changes back to product map
                setState(() {
                  widget.product["name"] = nameController.text;
                  widget.product["price"] = double.tryParse(priceController.text) ?? 0.0;
                  widget.product["stock"] = int.tryParse(stockController.text) ?? 0;
                });

                Navigator.pop(context); // go back to dashboard
              },
              child: const Text("Save Changes"),
            )
          ],
        ),
      ),
    );
  }
}