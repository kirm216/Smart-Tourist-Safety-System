import 'package:flutter/material.dart';

class TouristDashboard extends StatelessWidget {
  const TouristDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tourist Dashboard")),
      body: const Center(
        child: Text(
          "Welcome to Smart Tourist Safety System!",
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}
