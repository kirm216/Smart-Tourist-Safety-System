import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'admin_feedback_management_screen.dart';
import 'danger_zone_management_screen.dart';
import 'geofence_events_screen.dart';
import 'live_tourist_monitoring_screen.dart';
import 'admin_notifications_screen.dart';
import 'reports_analytics_screen.dart';
import 'safe_zone_management_screen.dart';
import 'sos_details_screen.dart';
import 'sos_management_screen.dart';
import 'tourists_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _firestore = FirebaseFirestore.instance;

  late final _usersStream = _firestore.collection('users').snapshots();
  late final _sosStream = _firestore.collection('sos_alerts').snapshots();
  late final _safeZonesStream = _firestore.collection('safe_zones').snapshots();
  late final _dangerZonesStream = _firestore
      .collection('danger_zones')
      .snapshots();
  late final _geofenceEventsStream = _firestore
      .collection('geo_fence_alerts')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Log out',
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: _DashboardStreams(
        usersStream: _usersStream,
        sosStream: _sosStream,
        safeZonesStream: _safeZonesStream,
        dangerZonesStream: _dangerZonesStream,
        geofenceEventsStream: _geofenceEventsStream,
        builder: (data) =>
            _DashboardContent(data: data, onRefresh: _refresh, onOpen: _open),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        _firestore
            .collection('users')
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('sos_alerts')
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('safe_zones')
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('danger_zones')
            .get(const GetOptions(source: Source.server)),
        _firestore
            .collection('geo_fence_alerts')
            .get(const GetOptions(source: Source.server)),
      ]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to refresh dashboard: $error')),
        );
    }
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _DashboardStreams extends StatelessWidget {
  const _DashboardStreams({
    required this.usersStream,
    required this.sosStream,
    required this.safeZonesStream,
    required this.dangerZonesStream,
    required this.geofenceEventsStream,
    required this.builder,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> sosStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> safeZonesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> dangerZonesStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>> geofenceEventsStream;
  final Widget Function(_DashboardData data) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: usersStream,
      builder: (context, usersSnapshot) {
        final state = _snapshotState(usersSnapshot);
        if (state != null) return state;
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sosStream,
          builder: (context, sosSnapshot) {
            final state = _snapshotState(sosSnapshot);
            if (state != null) return state;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: safeZonesStream,
              builder: (context, safeZonesSnapshot) {
                final state = _snapshotState(safeZonesSnapshot);
                if (state != null) return state;
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: dangerZonesStream,
                  builder: (context, dangerZonesSnapshot) {
                    final state = _snapshotState(dangerZonesSnapshot);
                    if (state != null) return state;
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: geofenceEventsStream,
                      builder: (context, geofenceSnapshot) {
                        final state = _snapshotState(geofenceSnapshot);
                        if (state != null) return state;
                        return builder(
                          _DashboardData(
                            users: usersSnapshot.data?.docs ?? const [],
                            sosAlerts: sosSnapshot.data?.docs ?? const [],
                            safeZones: safeZonesSnapshot.data?.docs ?? const [],
                            dangerZones:
                                dangerZonesSnapshot.data?.docs ?? const [],
                            geofenceEvents:
                                geofenceSnapshot.data?.docs ?? const [],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget? _snapshotState(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      return _DashboardMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load dashboard data',
        detail: snapshot.error.toString(),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }
}

class _DashboardData {
  const _DashboardData({
    required this.users,
    required this.sosAlerts,
    required this.safeZones,
    required this.dangerZones,
    required this.geofenceEvents,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sosAlerts;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> safeZones;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> dangerZones;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> geofenceEvents;
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
    required this.onRefresh,
    required this.onOpen,
  });

  final _DashboardData data;
  final Future<void> Function() onRefresh;
  final void Function(BuildContext context, Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final todayEvents = data.geofenceEvents.where((event) {
      final timestamp = _timestamp(event.data()['timestamp']);
      return timestamp != null &&
          timestamp.year == today.year &&
          timestamp.month == today.month &&
          timestamp.day == today.day;
    }).length;
    final activeAlerts = data.sosAlerts
        .where((alert) => !_isResolved(alert.data()))
        .toList();
    final resolvedAlerts = data.sosAlerts
        .where((alert) => _isResolved(alert.data()))
        .toList();
    final approvedTourists = data.users
        .where((user) => _approvalStatus(user.data()) == 'Approved')
        .length;
    final pendingTourists = data.users
        .where((user) => _approvalStatus(user.data()) == 'Pending')
        .length;
    final suspendedTourists = data.users
        .where((user) => _approvalStatus(user.data()) == 'Suspended')
        .length;
    final onlineTourists = data.users
        .where((user) => user.data()['isOnline'] == true)
        .length;

    final metrics = [
      _Metric(
        'Total Registered Tourists',
        data.users.length,
        Icons.people_alt_outlined,
        theme.colorScheme.primary,
      ),
      _Metric(
        'Approved Tourists',
        approvedTourists,
        Icons.verified_user_outlined,
        Colors.green,
      ),
      _Metric(
        'Pending Approval',
        pendingTourists,
        Icons.hourglass_top_outlined,
        Colors.orange,
      ),
      _Metric(
        'Suspended Tourists',
        suspendedTourists,
        Icons.person_off_outlined,
        theme.colorScheme.error,
      ),
      _Metric(
        'Online Tourists',
        onlineTourists,
        Icons.wifi_tethering,
        Colors.green,
      ),
      _Metric(
        'Offline Tourists',
        data.users.length - onlineTourists,
        Icons.wifi_off_outlined,
        Colors.grey,
      ),
      _Metric(
        'Active SOS Alerts',
        activeAlerts.length,
        Icons.crisis_alert_outlined,
        theme.colorScheme.error,
      ),
      _Metric(
        'Resolved SOS Alerts',
        resolvedAlerts.length,
        Icons.task_alt_outlined,
        theme.colorScheme.primary,
      ),
      _Metric(
        'Total Safe Zones',
        data.safeZones.length,
        Icons.shield_outlined,
        theme.colorScheme.secondary,
      ),
      _Metric(
        'Total Danger Zones',
        data.dangerZones.length,
        Icons.warning_amber_outlined,
        Colors.deepOrange,
      ),
      _Metric(
        "Today's Geofence Events",
        todayEvents,
        Icons.today_outlined,
        theme.colorScheme.tertiary,
      ),
      _Metric(
        'Total Geofence Events',
        data.geofenceEvents.length,
        Icons.location_on_outlined,
        theme.colorScheme.tertiary,
      ),
    ];

    final recentSos = [...data.sosAlerts]..sort(_compareNewest);
    final recentGeofence = [...data.geofenceEvents]..sort(_compareNewest);
    final recentUsers = [...data.users]..sort(_compareRegistrations);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MetricsGrid(metrics: metrics),
                  const SizedBox(height: 24),
                  _RecentSection(
                    title: 'Recent SOS Alerts',
                    emptyMessage: 'No SOS alerts found.',
                    children: recentSos.take(5).map((alert) {
                      final alertData = alert.data();
                      return _RecentSosTile(
                        name: _firstString(alertData, [
                          'fullName',
                          'userName',
                        ], fallback: 'Unnamed tourist'),
                        status: _sosStatus(alertData),
                        timestamp: _formatTimestamp(
                          _timestamp(alertData['timestamp']),
                        ),
                        onQuickView: () =>
                            onOpen(context, SosDetailsScreen(alert: alert)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _RecentSection(
                    title: 'Recent Geofence Events',
                    emptyMessage: 'No geofence events found.',
                    children: recentGeofence.take(5).map((event) {
                      final eventData = event.data();
                      return _RecentGeofenceTile(
                        name: _firstString(eventData, [
                          'userName',
                          'touristName',
                        ], fallback: 'Unnamed tourist'),
                        zone: _firstString(eventData, [
                          'safeZoneName',
                          'zoneName',
                        ], fallback: 'Unknown zone'),
                        eventType: _eventType(eventData),
                        timestamp: _formatTimestamp(
                          _timestamp(eventData['timestamp']),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  _RecentSection(
                    title: 'Recent Tourist Registrations',
                    emptyMessage: 'No tourist registrations found.',
                    children: recentUsers.take(5).map((user) {
                      final userData = user.data();
                      return _RecentRegistrationTile(
                        name: _firstString(userData, [
                          'fullName',
                        ], fallback: 'Unnamed tourist'),
                        email: _firstString(userData, [
                          'email',
                        ], fallback: 'Email not provided'),
                        registrationDate: _formatTimestamp(
                          _firstTimestamp(userData, [
                            'createdAt',
                            'registeredAt',
                            'registrationDate',
                            'createdOn',
                          ]),
                        ),
                        status: _approvalStatus(userData),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    icon: Icons.people_alt_outlined,
                    label: 'Manage Tourists',
                    onPressed: () => onOpen(context, const TouristsScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.map_outlined,
                    label: 'Live Tourist Monitoring',
                    onPressed: () =>
                        onOpen(context, const LiveTouristMonitoringScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.notifications_outlined,
                    label: 'Admin Notifications',
                    onPressed: () =>
                        onOpen(context, const AdminNotificationsScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.analytics_outlined,
                    label: 'Reports & Analytics',
                    onPressed: () =>
                        onOpen(context, const ReportsAnalyticsScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.crisis_alert_outlined,
                    label: 'Manage SOS Alerts',
                    onPressed: () =>
                        onOpen(context, const SosManagementScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.location_on_outlined,
                    label: 'Geo-fence Events',
                    onPressed: () =>
                        onOpen(context, const GeofenceEventsScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.shield_outlined,
                    label: 'Manage Safe Zones',
                    onPressed: () =>
                        onOpen(context, const SafeZoneManagementScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.warning_amber_outlined,
                    label: 'Manage Danger Zones',
                    onPressed: () =>
                        onOpen(context, const DangerZoneManagementScreen()),
                  ),
                  _ActionButton(
                    icon: Icons.feedback_outlined,
                    label: 'Feedback Management',
                    onPressed: () =>
                        onOpen(context, const AdminFeedbackManagementScreen()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 720
            ? 3
            : 2;
        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) => _MetricCard(metric: metrics[index]),
        );
      },
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(metric.icon, color: metric.color, size: 25),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${metric.value}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    metric.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.title,
    required this.emptyMessage,
    required this.children,
  });

  final String title;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(emptyMessage),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class _RecentSosTile extends StatelessWidget {
  const _RecentSosTile({
    required this.name,
    required this.status,
    required this.timestamp,
    required this.onQuickView,
  });

  final String name;
  final String status;
  final String timestamp;
  final VoidCallback onQuickView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved = status.toLowerCase() == 'resolved';
    final statusColor = resolved
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          spacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(timestamp, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Chip(
              label: Text(status),
              side: BorderSide(color: statusColor),
              labelStyle: TextStyle(color: statusColor),
              visualDensity: VisualDensity.compact,
            ),
            OutlinedButton.icon(
              onPressed: onQuickView,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Quick View'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentGeofenceTile extends StatelessWidget {
  const _RecentGeofenceTile({
    required this.name,
    required this.zone,
    required this.eventType,
    required this.timestamp,
  });

  final String name;
  final String zone;
  final String eventType;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(
          eventType == 'ENTER' ? Icons.login : Icons.logout,
          color: theme.colorScheme.tertiary,
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$zone · $timestamp'),
        trailing: Chip(
          label: Text(eventType),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _RecentRegistrationTile extends StatelessWidget {
  const _RecentRegistrationTile({
    required this.name,
    required this.email,
    required this.registrationDate,
    required this.status,
  });

  final String name;
  final String email;
  final String registrationDate;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: const Icon(Icons.person_add_alt_1_outlined),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('$email · $registrationDate'),
        trailing: Chip(
          label: Text(status),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
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
            Text(title, textAlign: TextAlign.center),
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

bool _isResolved(Map<String, dynamic> data) =>
    data['resolved'] == true ||
    _firstString(data, ['status']).toLowerCase() == 'resolved';

String _sosStatus(Map<String, dynamic> data) {
  if (_isResolved(data)) return 'Resolved';
  final status = _firstString(data, ['status']);
  return status.isEmpty ? 'Active' : status;
}

String _approvalStatus(Map<String, dynamic> data) {
  final status = _firstString(data, [
    'accountStatus',
    'approvalStatus',
    'status',
  ]).toLowerCase();
  if (status == 'approved' || status == 'active') return 'Approved';
  if (status == 'pending' || status == 'pending approval') return 'Pending';
  if (status == 'suspended') return 'Suspended';
  if (status.isEmpty) return 'Not provided';
  return status[0].toUpperCase() + status.substring(1);
}

String _eventType(Map<String, dynamic> data) {
  final eventType = _firstString(data, ['eventType']).toUpperCase();
  if (eventType == 'ENTERED') return 'ENTER';
  if (eventType == 'EXITED') return 'EXIT';
  return eventType.isEmpty ? 'UNKNOWN' : eventType;
}

String _firstString(
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

DateTime? _firstTimestamp(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final date = _timestamp(data[key]);
    if (date != null) return date;
  }
  return null;
}

DateTime? _timestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatTimestamp(DateTime? value) {
  if (value == null) return 'Not available';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

int _compareNewest(
  QueryDocumentSnapshot<Map<String, dynamic>> left,
  QueryDocumentSnapshot<Map<String, dynamic>> right,
) {
  final leftTimestamp = _timestamp(left.data()['timestamp']);
  final rightTimestamp = _timestamp(right.data()['timestamp']);
  if (leftTimestamp == null && rightTimestamp == null) return 0;
  if (leftTimestamp == null) return 1;
  if (rightTimestamp == null) return -1;
  return rightTimestamp.compareTo(leftTimestamp);
}

int _compareRegistrations(
  QueryDocumentSnapshot<Map<String, dynamic>> left,
  QueryDocumentSnapshot<Map<String, dynamic>> right,
) {
  final leftDate = _firstTimestamp(left.data(), [
    'createdAt',
    'registeredAt',
    'registrationDate',
    'createdOn',
  ]);
  final rightDate = _firstTimestamp(right.data(), [
    'createdAt',
    'registeredAt',
    'registrationDate',
    'createdOn',
  ]);
  if (leftDate == null && rightDate == null) return 0;
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  return rightDate.compareTo(leftDate);
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
