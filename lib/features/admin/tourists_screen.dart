import 'package:flutter/material.dart';

class TouristsScreen extends StatelessWidget {
  const TouristsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Tourists')),
      body: const Center(child: Text('Tourists Screen')),
    );
  }
}
