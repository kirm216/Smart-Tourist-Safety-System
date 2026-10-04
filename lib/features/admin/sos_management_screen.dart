import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sos_details_screen.dart';

class SosManagementScreen extends StatelessWidget {
  const SosManagementScreen({super.key});

  static final _alertsStream = FirebaseFirestore.instance
      .collection('sos_alerts')
      .orderBy('timestamp', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage SOS Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _alertsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load SOS alerts.',
              detail: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data?.docs ?? [];

          if (alerts.isEmpty) {
            return const _MessageState(
              icon: Icons.crisis_alert_outlined,
              message: 'No SOS alerts found.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _AlertCard(
              alert: alerts[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SosDetailsScreen(alert: alerts[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> alert;
  final VoidCallback onTap;

  Map<String, dynamic> get data => alert.data();

  String _text(String key, {String fallback = 'Not provided'}) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String _number(String key) {
    final value = data[key];
    if (value is num) return value.toString();
    return 'Not provided';
  }

  String _statusLabel() {
    final status = _text('status', fallback: 'Unknown');
    if (status.toLowerCase() == 'resolved' || data['resolved'] == true) {
      return 'Resolved';
    }
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'acknowledged':
        return 'Acknowledged';
      case 'in progress':
        return 'In Progress';
      default:
        return status;
    }
  }

  String _formattedTimestamp() {
    final value = data['timestamp'];
    final timestamp = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : null;
    if (timestamp == null) return 'Timestamp not available';

    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)} '
        '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel();
    final isResolved = statusLabel == 'Resolved';
    final statusColor = isResolved
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _text('fullName', fallback: 'Unnamed tourist'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(statusLabel),
                    avatar: Icon(
                      isResolved ? Icons.check_circle_outline : Icons.warning,
                      size: 18,
                      color: statusColor,
                    ),
                    side: BorderSide(color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _text('email'),
              ),
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Timestamp',
                value: _formattedTimestamp(),
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Latitude',
                value: _number('latitude'),
              ),
              _DetailRow(
                icon: Icons.explore_outlined,
                label: 'Longitude',
                value: _number('longitude'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.icon, required this.message, this.detail});

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
