import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

enum _ReportPeriod { today, last7Days, last30Days, custom }

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen> {
  static final _firestore = FirebaseFirestore.instance;
  static final _usersStream = _firestore.collection('users').snapshots();
  static final _sosStream = _firestore.collection('sos_alerts').snapshots();
  static final _safeZonesStream = _firestore
      .collection('safe_zones')
      .snapshots();
  static final _dangerZonesStream = _firestore
      .collection('danger_zones')
      .snapshots();
  static final _geofenceStream = _firestore
      .collection('geo_fence_alerts')
      .snapshots();

  _ReportPeriod _period = _ReportPeriod.last7Days;
  DateTimeRange? _customRange;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, usersSnapshot) {
          final state = _snapshotState(usersSnapshot);
          if (state != null) return state;
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sosStream,
            builder: (context, sosSnapshot) {
              final state = _snapshotState(sosSnapshot);
              if (state != null) return state;
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _safeZonesStream,
                builder: (context, safeZonesSnapshot) {
                  final state = _snapshotState(safeZonesSnapshot);
                  if (state != null) return state;
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _dangerZonesStream,
                    builder: (context, dangerZonesSnapshot) {
                      final state = _snapshotState(dangerZonesSnapshot);
                      if (state != null) return state;
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _geofenceStream,
                        builder: (context, geofenceSnapshot) {
                          final state = _snapshotState(geofenceSnapshot);
                          if (state != null) return state;
                          return _buildReports(
                            context,
                            _ReportsData(
                              users: usersSnapshot.data!.docs,
                              sos: sosSnapshot.data!.docs,
                              safeZones: safeZonesSnapshot.data!.docs,
                              dangerZones: dangerZonesSnapshot.data!.docs,
                              geofenceEvents: geofenceSnapshot.data!.docs,
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
      ),
    );
  }

  Widget? _snapshotState(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.hasError) {
      return _ReportMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Unable to load report data.',
        detail: snapshot.error.toString(),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    return null;
  }

  Widget _buildReports(BuildContext context, _ReportsData data) {
    final range = _resolvedRange(DateTime.now());
    final sos = data.sos.where((document) {
      return _isInRange(_timestamp(document.data()['timestamp']), range);
    }).toList();
    final events = data.geofenceEvents.where((document) {
      return _isInRange(_timestamp(document.data()['timestamp']), range);
    }).toList();

    final touristCounts = _touristCounts(data.users);
    final sosCounts = _sosCounts(sos);
    final safeZoneCounts = _zoneCounts(data.safeZones);
    final dangerZoneCounts = _zoneCounts(data.dangerZones);
    final geofenceCounts = _geofenceCounts(events);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PeriodSelector(
                    period: _period,
                    customRange: _customRange,
                    onSelected: _selectPeriod,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity period: ${_formatDate(range.start)} – ${_formatDate(range.end.subtract(const Duration(days: 1)))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (data.users.isEmpty &&
                      data.sos.isEmpty &&
                      data.safeZones.isEmpty &&
                      data.dangerZones.isEmpty &&
                      data.geofenceEvents.isEmpty) ...[
                    const SizedBox(height: 12),
                    const _ReportEmptyState(
                      message:
                          'No report data is available in the selected collections.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'Tourist Reports',
                    subtitle: 'Current tourist account and presence status',
                    child: _ReportMetricGrid(
                      metrics: [
                        _ReportMetric(
                          'Total Tourists',
                          touristCounts.total,
                          Icons.people_alt_outlined,
                        ),
                        _ReportMetric(
                          'Approved',
                          touristCounts.approved,
                          Icons.verified_user_outlined,
                          color: Colors.green,
                        ),
                        _ReportMetric(
                          'Pending',
                          touristCounts.pending,
                          Icons.hourglass_top_outlined,
                          color: Colors.orange,
                        ),
                        _ReportMetric(
                          'Suspended',
                          touristCounts.suspended,
                          Icons.person_off_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        _ReportMetric(
                          'Online',
                          touristCounts.online,
                          Icons.wifi_tethering,
                          color: Colors.green,
                        ),
                        _ReportMetric(
                          'Offline',
                          touristCounts.offline,
                          Icons.wifi_off_outlined,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'SOS Reports',
                    subtitle: 'Alert totals for the selected period',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ReportMetricGrid(
                          metrics: [
                            _ReportMetric(
                              'Total SOS',
                              sosCounts.total,
                              Icons.crisis_alert_outlined,
                            ),
                            _ReportMetric(
                              'Active',
                              sosCounts.active,
                              Icons.warning_amber_outlined,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            _ReportMetric(
                              'Acknowledged',
                              sosCounts.acknowledged,
                              Icons.mark_email_read_outlined,
                              color: Colors.orange,
                            ),
                            _ReportMetric(
                              'In Progress',
                              sosCounts.inProgress,
                              Icons.pending_actions_outlined,
                              color: Colors.blue,
                            ),
                            _ReportMetric(
                              'Resolved',
                              sosCounts.resolved,
                              Icons.task_alt_outlined,
                              color: Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SosTrendChart(alerts: sos, range: range),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'Safe Zone Reports',
                    subtitle: 'Current safe zone configuration',
                    child: _ReportMetricGrid(
                      metrics: [
                        _ReportMetric(
                          'Total Safe Zones',
                          safeZoneCounts.total,
                          Icons.shield_outlined,
                        ),
                        _ReportMetric(
                          'Enabled',
                          safeZoneCounts.enabled,
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        _ReportMetric(
                          'Disabled',
                          safeZoneCounts.disabled,
                          Icons.do_not_disturb_on_outlined,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'Danger Zone Reports',
                    subtitle: 'Current danger zone configuration',
                    child: _ReportMetricGrid(
                      metrics: [
                        _ReportMetric(
                          'Total Danger Zones',
                          dangerZoneCounts.total,
                          Icons.warning_amber_outlined,
                          color: Colors.deepOrange,
                        ),
                        _ReportMetric(
                          'Enabled',
                          dangerZoneCounts.enabled,
                          Icons.check_circle_outline,
                          color: Colors.green,
                        ),
                        _ReportMetric(
                          'Disabled',
                          dangerZoneCounts.disabled,
                          Icons.do_not_disturb_on_outlined,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'Geofence Event Reports',
                    subtitle: 'Events recorded during the selected period',
                    child: _ReportMetricGrid(
                      metrics: [
                        _ReportMetric(
                          'Total Events',
                          geofenceCounts.total,
                          Icons.location_on_outlined,
                        ),
                        _ReportMetric(
                          'ENTER',
                          geofenceCounts.enter,
                          Icons.login,
                          color: Colors.green,
                        ),
                        _ReportMetric(
                          'EXIT',
                          geofenceCounts.exit,
                          Icons.logout,
                          color: Colors.orange,
                        ),
                        _ReportMetric(
                          'Safe Zone Events',
                          geofenceCounts.safe,
                          Icons.shield_outlined,
                          color: Colors.teal,
                        ),
                        _ReportMetric(
                          'Danger Zone Events',
                          geofenceCounts.danger,
                          Icons.warning_amber_outlined,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPeriod(_ReportPeriod period) async {
    if (period != _ReportPeriod.custom) {
      setState(() {
        _period = period;
        _customRange = null;
      });
      return;
    }

    final now = DateTime.now();
    final reportRange = _resolvedRange(now);
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: reportRange.start,
            end: reportRange.end.subtract(const Duration(days: 1)),
          ),
      helpText: 'Select report date range',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _period = _ReportPeriod.custom;
      _customRange = selected;
    });
  }

  DateTimeRange _resolvedRange(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    late final DateTime start;
    late final DateTime end;
    switch (_period) {
      case _ReportPeriod.today:
        start = today;
        end = today.add(const Duration(days: 1));
      case _ReportPeriod.last7Days:
        start = today.subtract(const Duration(days: 6));
        end = today.add(const Duration(days: 1));
      case _ReportPeriod.last30Days:
        start = today.subtract(const Duration(days: 29));
        end = today.add(const Duration(days: 1));
      case _ReportPeriod.custom:
        final range = _customRange;
        if (range == null) {
          start = today;
          end = today.add(const Duration(days: 1));
        } else {
          start = DateTime(
            range.start.year,
            range.start.month,
            range.start.day,
          );
          end = DateTime(
            range.end.year,
            range.end.month,
            range.end.day,
          ).add(const Duration(days: 1));
        }
    }
    return DateTimeRange(start: start, end: end);
  }

  bool _isInRange(DateTime? date, DateTimeRange range) =>
      date != null && !date.isBefore(range.start) && date.isBefore(range.end);

  Future<void> _refresh() async {
    try {
      await Future.wait([
        for (final collection in [
          'users',
          'sos_alerts',
          'safe_zones',
          'danger_zones',
          'geo_fence_alerts',
        ])
          _firestore
              .collection(collection)
              .get(const GetOptions(source: Source.server)),
      ]);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Refresh failed: $error')));
    }
  }
}

class _ReportsData {
  const _ReportsData({
    required this.users,
    required this.sos,
    required this.safeZones,
    required this.dangerZones,
    required this.geofenceEvents,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> users;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> sos;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> safeZones;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> dangerZones;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> geofenceEvents;
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ReportMetricGrid extends StatelessWidget {
  const _ReportMetricGrid({required this.metrics});

  final List<_ReportMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 4
            : constraints.maxWidth >= 650
            ? 3
            : 2;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _ReportMetricCard(metric: metric),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ReportMetric {
  const _ReportMetric(this.label, this.value, this.icon, {this.color});

  final String label;
  final int value;
  final IconData icon;
  final Color? color;
}

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({required this.metric});

  final _ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = metric.color ?? theme.colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(metric.icon, color: color, size: 24),
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

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.period,
    required this.customRange,
    required this.onSelected,
  });

  final _ReportPeriod period;
  final DateTimeRange? customRange;
  final ValueChanged<_ReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _ReportPeriod.today: 'Today',
      _ReportPeriod.last7Days: 'Last 7 Days',
      _ReportPeriod.last30Days: 'Last 30 Days',
      _ReportPeriod.custom: customRange == null
          ? 'Custom Date Range'
          : '${_formatDate(customRange!.start)} – ${_formatDate(customRange!.end)}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Date Range', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_ReportPeriod>(
            segments: labels.entries
                .map(
                  (entry) =>
                      ButtonSegment(value: entry.key, label: Text(entry.value)),
                )
                .toList(),
            selected: {period},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onSelected(selection.first),
          ),
        ),
      ],
    );
  }
}

class _SosTrendChart extends StatelessWidget {
  const _SosTrendChart({required this.alerts, required this.range});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts;
  final DateTimeRange range;

  @override
  Widget build(BuildContext context) {
    final buckets = _makeBuckets(alerts, range);
    if (alerts.isEmpty) {
      return const _ReportEmptyState(
        message: 'No SOS trend data for this date range.',
      );
    }

    final theme = Theme.of(context);
    final maxValue = buckets.fold<int>(
      0,
      (maximum, bucket) => math.max(maximum, bucket.count),
    );
    final labelStep = math.max(1, (buckets.length / 5).ceil());

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SOS Alerts Over Time', style: theme.textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: math.max(1, maxValue + 1).toDouble(),
                  alignment: BarChartAlignment.spaceAround,
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          if (index % labelStep != 0 &&
                              index != buckets.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              buckets[index].label,
                              style: theme.textTheme.labelSmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < buckets.length; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: buckets[index].count.toDouble(),
                            color: theme.colorScheme.primary,
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_TrendBucket> _makeBuckets(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts,
    DateTimeRange range,
  ) {
    final days = range.end.difference(range.start).inDays;
    final bucketDays = days <= 30
        ? 1
        : days <= 90
        ? 7
        : 30;
    final result = <_TrendBucket>[];
    for (var start = range.start; start.isBefore(range.end);) {
      final end = start.add(Duration(days: bucketDays));
      final boundedEnd = end.isAfter(range.end) ? range.end : end;
      final count = alerts.where((alert) {
        final timestamp = _timestamp(alert.data()['timestamp']);
        return timestamp != null &&
            !timestamp.isBefore(start) &&
            timestamp.isBefore(boundedEnd);
      }).length;
      result.add(
        _TrendBucket(
          label: bucketDays == 1
              ? _formatMonthDay(start)
              : _formatMonthDay(start),
          count: count,
        ),
      );
      start = boundedEnd;
    }
    return result;
  }
}

class _TrendBucket {
  const _TrendBucket({required this.label, required this.count});

  final String label;
  final int count;
}

class _ReportCounts {
  const _ReportCounts(this.total, this.enabled, this.disabled);

  final int total;
  final int enabled;
  final int disabled;
}

class _TouristCounts {
  const _TouristCounts({
    required this.total,
    required this.approved,
    required this.pending,
    required this.suspended,
    required this.online,
    required this.offline,
  });

  final int total;
  final int approved;
  final int pending;
  final int suspended;
  final int online;
  final int offline;
}

class _SosCounts {
  const _SosCounts({
    required this.total,
    required this.active,
    required this.acknowledged,
    required this.inProgress,
    required this.resolved,
  });

  final int total;
  final int active;
  final int acknowledged;
  final int inProgress;
  final int resolved;
}

class _GeofenceCounts {
  const _GeofenceCounts({
    required this.total,
    required this.enter,
    required this.exit,
    required this.safe,
    required this.danger,
  });

  final int total;
  final int enter;
  final int exit;
  final int safe;
  final int danger;
}

_TouristCounts _touristCounts(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
) {
  var approved = 0;
  var pending = 0;
  var suspended = 0;
  var online = 0;
  final now = DateTime.now();
  for (final user in users) {
    final data = user.data();
    switch (_approvalStatus(data)) {
      case 'approved':
        approved++;
      case 'pending':
        pending++;
      case 'suspended':
        suspended++;
    }
    final updated = _timestamp(data['lastUpdated']);
    final recent =
        updated != null &&
        !updated.isAfter(now) &&
        now.difference(updated) <= const Duration(seconds: 30);
    if (data['isOnline'] == true && recent) online++;
  }
  return _TouristCounts(
    total: users.length,
    approved: approved,
    pending: pending,
    suspended: suspended,
    online: online,
    offline: users.length - online,
  );
}

_SosCounts _sosCounts(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts,
) {
  var active = 0;
  var acknowledged = 0;
  var inProgress = 0;
  var resolved = 0;
  for (final alert in alerts) {
    switch (_sosStatus(alert.data())) {
      case 'active':
        active++;
      case 'acknowledged':
        acknowledged++;
      case 'in progress':
        inProgress++;
      case 'resolved':
        resolved++;
    }
  }
  return _SosCounts(
    total: alerts.length,
    active: active,
    acknowledged: acknowledged,
    inProgress: inProgress,
    resolved: resolved,
  );
}

_ReportCounts _zoneCounts(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> zones,
) {
  final enabled = zones.where((zone) => _zoneIsEnabled(zone.data())).length;
  return _ReportCounts(zones.length, enabled, zones.length - enabled);
}

_GeofenceCounts _geofenceCounts(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> events,
) {
  var enter = 0;
  var exit = 0;
  var safe = 0;
  var danger = 0;
  for (final event in events) {
    final data = event.data();
    final type = _eventType(data);
    if (type == 'ENTER') enter++;
    if (type == 'EXIT') exit++;
    if (_isDangerEvent(data)) {
      danger++;
    } else {
      safe++;
    }
  }
  return _GeofenceCounts(
    total: events.length,
    enter: enter,
    exit: exit,
    safe: safe,
    danger: danger,
  );
}

bool _zoneIsEnabled(Map<String, dynamic> data) {
  final status = data['status'];
  if (status is bool) return status;
  if (status is String) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'enabled' || normalized == 'active';
  }
  return data['enabled'] == true || data['isEnabled'] == true;
}

String _approvalStatus(Map<String, dynamic> data) {
  final status = _stringValue(
    data['accountStatus'] ?? data['approvalStatus'] ?? data['status'],
  ).toLowerCase();
  if (status == 'approved' || status == 'active') return 'approved';
  if (status == 'pending' || status == 'pending approval') return 'pending';
  if (status == 'suspended') return 'suspended';
  return 'other';
}

String _sosStatus(Map<String, dynamic> data) {
  if (data['resolved'] == true) return 'resolved';
  final status = _stringValue(
    data['status'],
  ).toLowerCase().replaceAll('_', ' ');
  if (status.isEmpty) return 'active';
  if (status == 'resolved') return 'resolved';
  if (status == 'in progress') return 'in progress';
  if (status == 'acknowledged') return 'acknowledged';
  if (status == 'active') return 'active';
  return status;
}

String _eventType(Map<String, dynamic> data) {
  final type = _stringValue(data['eventType']).toLowerCase();
  if (type == 'enter' || type == 'entered') return 'ENTER';
  if (type == 'exit' || type == 'exited') return 'EXIT';
  return type.toUpperCase();
}

bool _isDangerEvent(Map<String, dynamic> data) {
  final zoneType = _stringValue(data['zoneType'] ?? data['type']).toLowerCase();
  return zoneType.contains('danger') ||
      _stringValue(data['dangerZoneId']).isNotEmpty ||
      _stringValue(data['dangerZoneName']).isNotEmpty;
}

String _stringValue(Object? value) => value is String ? value.trim() : '';

DateTime? _timestamp(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _formatMonthDay(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

class _ReportMessage extends StatelessWidget {
  const _ReportMessage({required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Center(
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
