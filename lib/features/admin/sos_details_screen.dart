import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SosDetailsScreen extends StatefulWidget {
  const SosDetailsScreen({
    super.key,
    required this.alert,
    this.source = 'sos_alert',
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> alert;
  final String source;

  @override
  State<SosDetailsScreen> createState() => _SosDetailsScreenState();
}

class _SosDetailsScreenState extends State<SosDetailsScreen> {
  bool _isUpdating = false;
  String _workflowStatus = 'Active';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Alert Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.alert.reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load SOS alert details.',
              detail: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final document = snapshot.data;
          if (document == null || !document.exists) {
            return const _MessageState(
              icon: Icons.crisis_alert_outlined,
              message: 'This SOS alert is no longer available.',
            );
          }

          final data = document.data() ?? <String, dynamic>{};
          final status = widget.source == 'hardware'
              ? _hardwareStatusLabel(data)
              : _statusLabel(data);
          final nextStatus = _nextStatus(status);
          final phone = _stringValue(data['phone'] ?? data['phoneNumber']);
          final resolvedAt = widget.source == 'hardware'
              ? _formatTimestamp(data['sosResolvedAt'])
              : _formatTimestamp(data['resolvedAt']);

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.source == 'hardware'
                                  ? _stringValue(data['uid'], fallback: widget.alert.id)
                                  : _stringValue(data['fullName'], fallback: 'Unnamed tourist'),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            _StatusBadge(status: status),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            if (widget.source == 'hardware') ...[
                              _DetailRow(
                                icon: Icons.tag_outlined,
                                label: 'Tourist ID',
                                value: _stringValue(data['uid'], fallback: widget.alert.id),
                              ),
                              _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Latitude',
                                value: _displayValue(data['latitude']),
                              ),
                              _DetailRow(
                                icon: Icons.explore_outlined,
                                label: 'Longitude',
                                value: _displayValue(data['longitude']),
                              ),
                              _DetailRow(
                                icon: Icons.gps_fixed_outlined,
                                label: 'GPS validity',
                                value: _gpsStatus(data['gpsValid']),
                              ),
                              _DetailRow(
                                icon: Icons.crisis_alert_outlined,
                                label: 'SOS triggered time',
                                value: _formatTimestamp(data['sosTriggeredAt']),
                              ),
                              _DetailRow(
                                icon: Icons.schedule_outlined,
                                label: 'Last updated',
                                value: _formatTimestamp(data['lastUpdated']),
                              ),
                              _DetailRow(
                                icon: Icons.format_list_numbered_rounded,
                                label: 'Sequence',
                                value: _displayValue(data['sequence']),
                              ),
                              _DetailRow(
                                icon: Icons.signal_cellular_alt_2_bar_outlined,
                                label: 'RSSI',
                                value: _displayValue(data['rssi']),
                              ),
                              _DetailRow(
                                icon: Icons.flag_outlined,
                                label: 'Current SOS status',
                                value: status,
                              ),
                            ] else ...[
                              _DetailRow(
                                icon: Icons.email_outlined,
                                label: 'Email',
                                value: _displayValue(data['email']),
                              ),
                              if (phone.isNotEmpty)
                                _DetailRow(
                                  icon: Icons.phone_outlined,
                                  label: 'Phone Number',
                                  value: phone,
                                ),
                              _DetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Latitude',
                                value: _displayValue(data['latitude']),
                              ),
                              _DetailRow(
                                icon: Icons.explore_outlined,
                                label: 'Longitude',
                                value: _displayValue(data['longitude']),
                              ),
                              _DetailRow(
                                icon: Icons.schedule_outlined,
                                label: 'Timestamp',
                                value: _formatTimestamp(data['timestamp']),
                              ),
                              _DetailRow(
                                icon: Icons.flag_outlined,
                                label: 'Current Status',
                                value: status,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: nextStatus == null
                      ? _ResolvedBadge(timestamp: resolvedAt)
                      : SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isUpdating
                                ? null
                                : () => _updateStatus(
                                    document.reference,
                                    nextStatus,
                                  ),
                            icon: _isUpdating
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_actionLabel(status)),
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

  Future<void> _updateStatus(
    DocumentReference<Map<String, dynamic>> reference,
    String status,
  ) async {
    setState(() => _isUpdating = true);

    if (widget.source == 'hardware') {
      final updates = <String, dynamic>{
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (status == 'Resolved') {
        updates['sosActive'] = false;
        updates['sosResolvedAt'] = FieldValue.serverTimestamp();
      } else {
        _workflowStatus = status;
      }

      try {
        await reference.update(updates);
        if (!mounted) return;
        if (status != 'Resolved') {
          setState(() => _workflowStatus = status);
        } else {
          setState(() => _workflowStatus = 'Resolved');
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Status updated to $status.')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Unable to update status: $error')),
          );
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
      return;
    }

    final updates = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == 'Resolved') {
      updates['resolvedAt'] = FieldValue.serverTimestamp();
    }

    try {
      await reference.update(updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Status updated to $status.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to update status: $error')),
        );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String _hardwareStatusLabel(Map<String, dynamic> data) {
    if (data['sosActive'] == false) return 'Resolved';
    if (_workflowStatus.isNotEmpty &&
        _workflowStatus != 'Active' &&
        _workflowStatus != 'Acknowledged' &&
        _workflowStatus != 'In Progress') {
      return 'Active';
    }
    return _workflowStatus.isEmpty ? 'Active' : _workflowStatus;
  }

  static String _statusLabel(Map<String, dynamic> data) {
    final rawStatus = _stringValue(data['status']);
    if (rawStatus.toLowerCase() == 'resolved' || data['resolved'] == true) {
      return 'Resolved';
    }
    switch (rawStatus.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'acknowledged':
        return 'Acknowledged';
      case 'in progress':
        return 'In Progress';
      default:
        return rawStatus.isEmpty ? 'Unknown' : rawStatus;
    }
  }

  static String _gpsStatus(Object? value) {
    if (value is bool) {
      return value ? 'Valid' : 'Invalid';
    }
    return 'Unknown';
  }

  static String? _nextStatus(String status) {
    switch (status) {
      case 'Active':
        return 'Acknowledged';
      case 'Acknowledged':
        return 'In Progress';
      case 'In Progress':
        return 'Resolved';
      default:
        return null;
    }
  }

  static String _actionLabel(String status) {
    switch (status) {
      case 'Active':
        return 'Acknowledge';
      case 'Acknowledged':
        return 'Mark In Progress';
      default:
        return 'Resolve';
    }
  }

  static String _stringValue(Object? value, {String fallback = ''}) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;

  static String _displayValue(Object? value) {
    if (value is num) return value.toString();
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? 'Not available' : text;
  }

  static String _formatTimestamp(Object? value) {
    final timestamp = value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : value is String
        ? _parseStringTimestamp(value)
        : null;
    if (timestamp == null) return 'Not available';

    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${timestamp.year}-${twoDigits(timestamp.month)}-${twoDigits(timestamp.day)} '
        '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:${twoDigits(timestamp.second)}';
  }

  static DateTime? _parseStringTimestamp(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
    final isoValue = value.endsWith('Z') ? value.replaceFirst('Z', '+00:00') : value;
    return DateTime.tryParse(isoValue);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final isResolved = status == 'Resolved';
    final color = isResolved
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Chip(
      avatar: Icon(
        isResolved ? Icons.check_circle_outline : Icons.crisis_alert_outlined,
        size: 18,
        color: color,
      ),
      label: Text(status),
      side: BorderSide(color: color),
      backgroundColor: isResolved ? Colors.green.withValues(alpha: 0.1) : null,
    );
  }
}

class _ResolvedBadge extends StatelessWidget {
  const _ResolvedBadge({required this.timestamp});

  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_outline, color: Colors.green),
      label: Text(
        timestamp == 'Not available' ? 'Resolved' : 'Resolved · $timestamp',
        style: const TextStyle(color: Colors.green),
      ),
      side: const BorderSide(color: Colors.green),
      backgroundColor: Colors.green.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 140,
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
