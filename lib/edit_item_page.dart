import 'package:flutter/material.dart';
import 'services/firestore_service.dart';

class EditItemPage extends StatefulWidget {
  final String? productId;
  final String businessId;
  final Map<String, dynamic> product;

  const EditItemPage({
    Key? key,
    this.productId,
    required this.businessId,
    required this.product,
  }) : super(key: key);

  @override
  State<EditItemPage> createState() => _EditItemPageState();
}

class _EditItemPageState extends State<EditItemPage> {
  late TextEditingController nameController;
  late TextEditingController descriptionController;
  late TextEditingController priceController;
  late TextEditingController quantityController;
  late TextEditingController unitController;
  late TextEditingController categoryController;

  final FirestoreService _firestoreService = FirestoreService();

  bool get isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.product["name"] ?? "",
    );

    descriptionController = TextEditingController(
      text: widget.product["description"] ?? "",
    );

    priceController = TextEditingController(
      text: widget.product["price"]?.toString() ?? "",
    );

    quantityController = TextEditingController(
      text: widget.product["quantity"]?.toString() ?? "",
    );

    unitController = TextEditingController(
      text: widget.product["unit"] ?? "",
    );

    categoryController = TextEditingController(
      text: widget.product["category"] ?? "",
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    unitController.dispose();
    categoryController.dispose();
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

            const SizedBox(height: 15),

            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Price",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: unitController,
              decoration: const InputDecoration(
                labelText: "Unit (e.g. ea, lb, etc.)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: categoryController,
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () async {
                try {
                  final name = nameController.text;
                  final description = descriptionController.text;
                  final price = double.tryParse(priceController.text) ?? 0;
                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  final unit = unitController.text;
                  final category = categoryController.text;

                  if (isEdit) {
                    await _firestoreService.updateProduct(
                      productId: widget.productId!,
                      name: name,
                      description: description,
                      price: price,
                      quantity: quantity,
                      unit: unit,
                      category: category,
                    );
                  } else {
                    await _firestoreService.addProduct(
                      businessId: widget.businessId,
                      name: name,
                      description: description,
                      price: price,
                      quantity: quantity,
                      unit: unit,
                      category: category,
                    );
                  }

                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}