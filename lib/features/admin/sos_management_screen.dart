import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'sos_details_screen.dart';

class SosManagementScreen extends StatefulWidget {
  const SosManagementScreen({super.key});

  @override
  State<SosManagementScreen> createState() => _SosManagementScreenState();
}

class _SosManagementScreenState extends State<SosManagementScreen> {
  static const _statuses = [
    'All',
    'Active',
    'Acknowledged',
    'In Progress',
    'Resolved',
  ];

  static final _alertsStream = FirebaseFirestore.instance
      .collection('sos_alerts')
      .orderBy('timestamp', descending: true)
      .snapshots();

  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

          final allAlerts = snapshot.data?.docs ?? [];
          final activeCount = allAlerts
              .where((alert) => _alertStatus(alert.data()) == 'Active')
              .length;
          final resolvedCount = allAlerts
              .where((alert) => _alertStatus(alert.data()) == 'Resolved')
              .length;
          final query = _searchQuery.trim().toLowerCase();
          final alerts = allAlerts.where((alert) {
            final data = alert.data();
            final matchesStatus =
                _selectedStatus == 'All' ||
                _alertStatus(data) == _selectedStatus;
            final name = (data['fullName'] ?? data['touristName'] ?? '')
                .toString()
                .toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final matchesSearch =
                query.isEmpty || name.contains(query) || email.contains(query);
            return matchesStatus && matchesSearch;
          }).toList();
          alerts.sort((left, right) {
            final leftTimestamp = _alertTimestamp(left.data());
            final rightTimestamp = _alertTimestamp(right.data());
            if (leftTimestamp == null && rightTimestamp == null) return 0;
            if (leftTimestamp == null) return 1;
            if (rightTimestamp == null) return -1;
            return _newestFirst
                ? rightTimestamp.compareTo(leftTimestamp)
                : leftTimestamp.compareTo(rightTimestamp);
          });

          return Column(
            children: [
              _ManagementControls(
                controller: _searchController,
                statuses: _statuses,
                selectedStatus: _selectedStatus,
                newestFirst: _newestFirst,
                totalCount: allAlerts.length,
                activeCount: activeCount,
                resolvedCount: resolvedCount,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onStatusChanged: (value) =>
                    setState(() => _selectedStatus = value),
                onSortChanged: (value) => setState(() => _newestFirst = value),
              ),
              Expanded(
                child: alerts.isEmpty
                    ? _MessageState(
                        icon: Icons.crisis_alert_outlined,
                        message: allAlerts.isEmpty
                            ? 'No SOS alerts found.'
                            : 'No alerts match these filters.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: alerts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _AlertCard(
                          alert: alerts[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SosDetailsScreen(alert: alerts[index]),
                            ),
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

class _ManagementControls extends StatelessWidget {
  const _ManagementControls({
    required this.controller,
    required this.statuses,
    required this.selectedStatus,
    required this.newestFirst,
    required this.totalCount,
    required this.activeCount,
    required this.resolvedCount,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final List<String> statuses;
  final String selectedStatus;
  final bool newestFirst;
  final int totalCount;
  final int activeCount;
  final int resolvedCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<bool> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by tourist or email',
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text('Status', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: statuses
                .map(
                  (status) => ChoiceChip(
                    label: Text(status),
                    selected: selectedStatus == status,
                    onSelected: (_) => onStatusChanged(status),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Sort by', style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<bool>(
                  initialValue: newestFirst,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Newest First')),
                    DropdownMenuItem(value: false, child: Text('Oldest First')),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total Alerts',
                  count: totalCount,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Active Alerts',
                  count: activeCount,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Resolved Alerts',
                  count: resolvedCount,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _alertStatus(Map<String, dynamic> data) {
  final rawStatus = data['status'] is String
      ? (data['status'] as String).trim()
      : '';
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

DateTime? _alertTimestamp(Map<String, dynamic> data) {
  final value = data['timestamp'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
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
