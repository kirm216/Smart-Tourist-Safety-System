import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sos_details_screen.dart';

class SosManagementScreen extends StatelessWidget {
  const SosManagementScreen({super.key});

  static final _alertsStream = FirebaseFirestore.instance
      .collection('sos_alerts')
      .snapshots();
  static final _touristsStream = FirebaseFirestore.instance
      .collection('tourists')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage SOS Alerts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _alertsStream,
        builder: (context, alertsSnapshot) {
          if (alertsSnapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load SOS alerts.',
              detail: alertsSnapshot.error.toString(),
            );
          }
          if (alertsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _touristsStream,
            builder: (context, touristsSnapshot) {
              if (touristsSnapshot.hasError) {
                return _MessageState(
                  icon: Icons.cloud_off_outlined,
                  message: 'Unable to load hardware SOS alerts.',
                  detail: touristsSnapshot.error.toString(),
                );
              }
              if (touristsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final alerts = [
                ..._normalizeSosAlerts(alertsSnapshot.data?.docs ?? const []),
                ..._normalizeHardwareAlerts(
                  touristsSnapshot.data?.docs ?? const [],
                ),
              ]..sort(_compareAlerts);

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
                itemBuilder: (context, index) => _AlertCard(alert: alerts[index]),
              );
            },
          );
        },
      ),
    );
  }

  static List<_NormalizedAlert> _normalizeSosAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((document) => !_isResolved(document.data()))
        .map((document) => _NormalizedAlert.fromSosDocument(document))
        .toList();
  }

  static List<_NormalizedAlert> _normalizeHardwareAlerts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((document) => document.data()['sosActive'] == true)
        .map((document) => _NormalizedAlert.fromHardwareDocument(document))
        .toList();
  }

  static int _compareAlerts(_NormalizedAlert left, _NormalizedAlert right) {
    if (left.timestamp == null && right.timestamp == null) return 0;
    if (left.timestamp == null) return 1;
    if (right.timestamp == null) return -1;
    return right.timestamp!.compareTo(left.timestamp!);
  }

  static bool _isResolved(Map<String, dynamic> data) {
    final status = _stringValue(data['status']).toLowerCase();
    return data['resolved'] == true || status == 'resolved';
  }

  static String _stringValue(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return '';
  }
}

class _NormalizedAlert {
  const _NormalizedAlert({
    required this.document,
    required this.source,
    required this.title,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final String source;
  final String title;
  final DateTime? timestamp;
  final num? latitude;
  final num? longitude;
  final String status;

  factory _NormalizedAlert.fromSosDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final title = _stringValue(data['fullName'], fallback: 'Unnamed tourist');
    final timestamp = _timestamp(data['timestamp']);
    return _NormalizedAlert(
      document: document,
      source: 'sos_alert',
      title: title,
      timestamp: timestamp,
      latitude: data['latitude'] is num ? data['latitude'] as num : null,
      longitude: data['longitude'] is num ? data['longitude'] as num : null,
      status: _statusFor(data),
    );
  }

  factory _NormalizedAlert.fromHardwareDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final touristId = _stringValue(data['uid'], fallback: document.id);
    final timestamp = _timestamp(data['sosTriggeredAt']) ?? _timestamp(data['lastUpdated']);
    return _NormalizedAlert(
      document: document,
      source: 'hardware',
      title: touristId,
      timestamp: timestamp,
      latitude: data['latitude'] is num ? data['latitude'] as num : null,
      longitude: data['longitude'] is num ? data['longitude'] as num : null,
      status: data['sosActive'] == true ? 'Active' : 'Resolved',
    );
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final isoValue = value.endsWith('Z') ? value.replaceFirst('Z', '+00:00') : value;
      return DateTime.tryParse(isoValue);
    }
    return null;
  }

  static String _statusFor(Map<String, dynamic> data) {
    final status = _stringValue(data['status']);
    if (status.isEmpty) return 'Active';
    return status;
  }

  static String _stringValue(Object? value, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? fallback : text;
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final _NormalizedAlert alert;

  String _formattedTimestamp() {
    final timestamp = alert.timestamp;
    if (timestamp == null) return 'Timestamp not available';
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)} '
        '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = alert.status.toLowerCase() != 'resolved';
    final statusColor = isActive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SosDetailsScreen(
                alert: alert.document,
                source: alert.source,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      alert.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(isActive ? 'Active' : 'Resolved'),
                    avatar: Icon(
                      isActive ? Icons.warning : Icons.check_circle_outline,
                      size: 18,
                      color: statusColor,
                    ),
                    side: BorderSide(color: statusColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (alert.source == 'hardware') ...[
                _DetailRow(
                  icon: Icons.tag_outlined,
                  label: 'Tourist ID',
                  value: alert.title,
                ),
              ],
              if (alert.source != 'hardware') ...[
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _textValue(alert.document.data()['email']),
                ),
              ],
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Timestamp',
                value: _formattedTimestamp(),
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Latitude',
                value: alert.latitude == null ? 'Not provided' : alert.latitude.toString(),
              ),
              _DetailRow(
                icon: Icons.explore_outlined,
                label: 'Longitude',
                value: alert.longitude == null ? 'Not provided' : alert.longitude.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _textValue(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? 'Not provided' : text;
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
