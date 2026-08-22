import 'package:flutter/material.dart';

class SafeZoneManagementScreen extends StatelessWidget {
  const SafeZoneManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Safe Zones')),
      body: const Center(child: Text('Safe Zone Management Screen')),
    );
  }
}
