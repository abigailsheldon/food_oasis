import 'package:flutter/material.dart';

class ProductIcons {
  static const Map<String, IconData> options = {
    'default': Icons.fastfood,
    'fruit': Icons.apple,
    'vegetable': Icons.eco,
    'dairy': Icons.egg,
    'meat': Icons.set_meal,
    'bakery': Icons.bakery_dining,
    'drink': Icons.local_drink,
    'snack': Icons.cookie,
    'seafood': Icons.set_meal_outlined,
  };

  static IconData fromKey(String? key) {
    return options[key ?? 'default'] ?? Icons.fastfood;
  }
}