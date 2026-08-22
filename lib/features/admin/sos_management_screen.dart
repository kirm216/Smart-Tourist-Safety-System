import 'package:flutter/material.dart';

class SosManagementScreen extends StatelessWidget {
  const SosManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage SOS Alerts')),
      body: const Center(child: Text('SOS Management Screen')),
    );
  }
}
