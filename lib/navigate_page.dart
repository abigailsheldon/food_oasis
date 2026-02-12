import 'package:flutter/material.dart';

class NavigatePage extends StatelessWidget {
  const NavigatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigate'),
      ),
      body: Center(
        child: Text('Navigate to Fresh Food'),
      ),
    );
  }
}