import 'package:flutter/material.dart';

class GeofenceEventsScreen extends StatelessWidget {
  const GeofenceEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geo-fence Events')),
      body: const Center(child: Text('Geo-fence Events Screen')),
    );
  }
}
