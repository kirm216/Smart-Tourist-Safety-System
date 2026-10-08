import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GeofenceEventDetailsScreen extends StatefulWidget {
  const GeofenceEventDetailsScreen({super.key, required this.event});

  final QueryDocumentSnapshot<Map<String, dynamic>> event;

  @override
  State<GeofenceEventDetailsScreen> createState() =>
      _GeofenceEventDetailsScreenState();
}

class _GeofenceEventDetailsScreenState
    extends State<GeofenceEventDetailsScreen> {
  bool _isMarkingRead = false;

  Future<void> _markAsRead() async {
    if (_isMarkingRead) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isMarkingRead = true);
    try {
      await widget.event.reference.update({'status': 'read'});
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Event marked as read.')));
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to mark event as read: $error')),
        );
    } finally {
      if (mounted) setState(() => _isMarkingRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geofence Event Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.event.reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load event details.',
              detail: snapshot.error.toString(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final document = snapshot.data;
          if (document == null || !document.exists) {
            return const _MessageState(
              icon: Icons.location_searching_outlined,
              message: 'This geofence event is no longer available.',
            );
          }

          final data = document.data() ?? <String, dynamic>{};
          final zoneType = _zoneType(data);
          final zoneColor = _zoneColor(context, zoneType);
          final eventStatus = _eventStatus(data);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: zoneColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: zoneColor,
                              child: Icon(
                                zoneType == 'Safe'
                                    ? Icons.shield_outlined
                                    : Icons.warning_amber_outlined,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _eventType(data),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_safeZoneName(data)} · $zoneType Zone',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      title: 'Tourist',
                      children: [
                        _DetailRow(
                          icon: Icons.person_outline,
                          label: 'User Name',
                          value: _touristName(data),
                        ),
                        _DetailRow(
                          icon: Icons.email_outlined,
                          label: 'User Email',
                          value: _displayValue(_touristEmail(data)),
                        ),
                        _DetailRow(
                          icon: Icons.badge_outlined,
                          label: 'User ID',
                          value: _displayValue(_firstText(data, ['userId'])),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      title: 'Safe Zone',
                      children: [
                        _DetailRow(
                          icon: Icons.place_outlined,
                          label: 'Safe Zone Name',
                          value: _safeZoneName(data),
                        ),
                        _DetailRow(
                          icon: Icons.fingerprint_outlined,
                          label: 'Safe Zone ID',
                          value: _displayValue(
                            _firstText(data, ['safeZoneId']),
                          ),
                        ),
                        if (_firstText(data, ['zoneType']).isNotEmpty)
                          _DetailRow(
                            icon: Icons.category_outlined,
                            label: 'Zone Type',
                            value: '$zoneType Zone',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _DetailsSection(
                      title: 'Event',
                      children: [
                        _DetailRow(
                          icon: Icons.swap_vert_circle_outlined,
                          label: 'Event Type',
                          value: _eventType(data),
                        ),
                        _DetailRow(
                          icon: Icons.schedule_outlined,
                          label: 'Timestamp',
                          value: _formatTimestamp(data['timestamp']),
                        ),
                        _DetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Latitude',
                          value: _numberValue(data['latitude']),
                        ),
                        _DetailRow(
                          icon: Icons.explore_outlined,
                          label: 'Longitude',
                          value: _numberValue(data['longitude']),
                        ),
                        _DetailRow(
                          icon: Icons.mark_email_read_outlined,
                          label: 'Status',
                          value: eventStatus,
                        ),
                        if (_firstText(data, ['deviceId']).isNotEmpty)
                          _DetailRow(
                            icon: Icons.devices_outlined,
                            label: 'Device ID',
                            value: _firstText(data, ['deviceId']),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: eventStatus == 'Unread'
                      ? SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isMarkingRead ? null : _markAsRead,
                            icon: _isMarkingRead
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.mark_email_read_outlined),
                            label: const Text('Mark as Read'),
                          ),
                        )
                      : const Center(
                          child: Chip(
                            avatar: Icon(Icons.mark_email_read_outlined),
                            label: Text('Read'),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
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

String _touristName(Map<String, dynamic> data) =>
    _firstText(data, ['userName', 'touristName'], fallback: 'Unknown user');

String _touristEmail(Map<String, dynamic> data) =>
    _firstText(data, ['userEmail', 'touristEmail']);

String _safeZoneName(Map<String, dynamic> data) =>
    _firstText(data, ['safeZoneName', 'zoneName'], fallback: 'Unknown zone');

String _zoneType(Map<String, dynamic> data) {
  final type = _firstText(data, ['zoneType']);
  switch (type.toLowerCase()) {
    case 'safe':
      return 'Safe';
    case 'danger':
      return 'Danger';
    default:
      return type.isEmpty ? 'Safe' : type;
  }
}

String _eventType(Map<String, dynamic> data) {
  final type = _firstText(data, ['eventType']).toUpperCase();
  switch (type) {
    case 'ENTER':
    case 'ENTERED':
      return 'ENTER';
    case 'EXIT':
    case 'EXITED':
      return 'EXIT';
    default:
      return type.isEmpty ? 'Unknown' : type;
  }
}

String _eventStatus(Map<String, dynamic> data) =>
    _firstText(data, ['status']).toLowerCase() == 'read' ? 'Read' : 'Unread';

String _firstText(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return fallback;
}

String _displayValue(String value) => value.isEmpty ? 'Not provided' : value;

String _numberValue(Object? value) {
  if (value is num) return value.toString();
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return 'Not provided';
}

String _formatTimestamp(Object? value) {
  final dateTime = value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
  if (dateTime == null) return 'Not available';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
}

Color _zoneColor(BuildContext context, String zoneType) {
  switch (zoneType.toLowerCase()) {
    case 'safe':
      return Colors.green;
    case 'danger':
      return Colors.red;
    default:
      return Theme.of(context).colorScheme.outline;
  }
}
