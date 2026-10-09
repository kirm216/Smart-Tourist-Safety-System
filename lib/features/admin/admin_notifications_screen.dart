import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

enum _NotificationFilter { all, unread, read, sos, geofence, registration }

enum _NotificationSort { newest, oldest }

enum _NotificationKind {
  registration,
  sosCreated,
  sosStatus,
  safeEntry,
  safeExit,
  dangerEntry,
  dangerExit,
  general,
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  static final _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();
  static final _sosStream = FirebaseFirestore.instance
      .collection('sos_alerts')
      .snapshots();
  static final _geofenceStream = FirebaseFirestore.instance
      .collection('geo_fence_alerts')
      .snapshots();

  static const _filterLabels = {
    _NotificationFilter.all: 'All',
    _NotificationFilter.unread: 'Unread',
    _NotificationFilter.read: 'Read',
    _NotificationFilter.sos: 'SOS',
    _NotificationFilter.geofence: 'Geofence',
    _NotificationFilter.registration: 'Registration',
  };

  final _searchController = TextEditingController();
  String _searchQuery = '';
  _NotificationFilter _filter = _NotificationFilter.all;
  _NotificationSort _sort = _NotificationSort.newest;
  bool _isUpdating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Notifications'),
        actions: [
          PopupMenuButton<_NotificationSort>(
            tooltip: 'Sort notifications',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _NotificationSort.newest,
                child: Text('Newest first'),
              ),
              PopupMenuItem(
                value: _NotificationSort.oldest,
                child: Text('Oldest first'),
              ),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) return _error(usersSnapshot.error);
          if (!usersSnapshot.hasData) return _loading();
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _sosStream,
            builder: (context, sosSnapshot) {
              if (sosSnapshot.hasError) return _error(sosSnapshot.error);
              if (!sosSnapshot.hasData) return _loading();
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _geofenceStream,
                builder: (context, geofenceSnapshot) {
                  if (geofenceSnapshot.hasError) {
                    return _error(geofenceSnapshot.error);
                  }
                  if (!geofenceSnapshot.hasData) return _loading();
                  final notifications = _derive(
                    usersSnapshot.data!.docs,
                    sosSnapshot.data!.docs,
                    geofenceSnapshot.data!.docs,
                  );
                  return _content(context, notifications);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<_AdminNotification> notifications,
  ) {
    final counts = _NotificationCounts.from(notifications);
    final query = _searchQuery.trim().toLowerCase();
    final visible = notifications.where((notification) {
      final matchesName = notification.touristName.toLowerCase().contains(
        query,
      );
      final matchesFilter = switch (_filter) {
        _NotificationFilter.all => true,
        _NotificationFilter.unread => !notification.isRead,
        _NotificationFilter.read => notification.isRead,
        _NotificationFilter.sos => notification.category == 'SOS',
        _NotificationFilter.geofence => notification.category == 'Geofence',
        _NotificationFilter.registration =>
          notification.category == 'Registration',
      };
      return matchesName && matchesFilter;
    }).toList()..sort(_compare);

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
                  _SummaryGrid(counts: counts),
                  const SizedBox(height: 12),
                  SearchBar(
                    controller: _searchController,
                    leading: const Icon(Icons.search),
                    hintText: 'Search by tourist name',
                    trailing: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                    ],
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterLabels.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _filter == entry.key,
                            onSelected: (_) =>
                                setState(() => _filter = entry.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: counts.unread == 0 || _isUpdating
                          ? null
                          : () => _markAllRead(notifications),
                      icon: _isUpdating
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.done_all),
                      label: const Text('Mark All as Read'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _message(
                Icons.notifications_none_outlined,
                notifications.isEmpty
                    ? 'No notifications yet.'
                    : 'No notifications match this search or filter.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _NotificationCard(
                  notification: visible[index],
                  onToggle: _isUpdating
                      ? null
                      : () => _toggleRead(visible[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());

  Widget _error(Object? error) => _message(
    Icons.cloud_off_outlined,
    'Unable to load notifications.',
    detail: error?.toString(),
  );

  Widget _message(IconData icon, String title, {String? detail}) =>
      _NotificationMessage(icon: icon, title: title, detail: detail);

  Future<void> _refresh() async {
    try {
      await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .get(const GetOptions(source: Source.server)),
        FirebaseFirestore.instance
            .collection('sos_alerts')
            .get(const GetOptions(source: Source.server)),
        FirebaseFirestore.instance
            .collection('geo_fence_alerts')
            .get(const GetOptions(source: Source.server)),
      ]);
    } catch (error) {
      if (mounted) _showMessage('Unable to refresh notifications: $error');
    }
  }

  Future<void> _toggleRead(_AdminNotification notification) async {
    setState(() => _isUpdating = true);
    try {
      await notification.reference.update({
        notification.readField: notification.isRead
            ? notification.unreadValue
            : notification.readValue,
      });
    } catch (error) {
      if (mounted) _showMessage('Unable to update notification: $error');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _markAllRead(List<_AdminNotification> notifications) async {
    final updates = <String, _DocumentUpdate>{};
    for (final notification in notifications.where((item) => !item.isRead)) {
      final update = updates.putIfAbsent(
        notification.reference.path,
        () => _DocumentUpdate(notification.reference),
      );
      update.fields[notification.readField] = notification.readValue;
    }

    setState(() => _isUpdating = true);
    try {
      final documents = updates.values.toList();
      for (var offset = 0; offset < documents.length; offset += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final update in documents.skip(offset).take(400)) {
          batch.update(update.reference, update.fields);
        }
        await batch.commit();
      }
    } catch (error) {
      if (mounted) _showMessage('Unable to mark all as read: $error');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  int _compare(_AdminNotification left, _AdminNotification right) {
    if (left.timestamp == null && right.timestamp == null) return 0;
    if (left.timestamp == null) return 1;
    if (right.timestamp == null) return -1;
    return _sort == _NotificationSort.newest
        ? right.timestamp!.compareTo(left.timestamp!)
        : left.timestamp!.compareTo(right.timestamp!);
  }

  List<_AdminNotification> _derive(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sosAlerts,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> geofenceEvents,
  ) {
    final result = <_AdminNotification>[];

    for (final user in users) {
      final data = user.data();
      result.add(
        _AdminNotification(
          id: 'registration-${user.id}',
          kind: _NotificationKind.registration,
          reference: user.reference,
          readField: 'registrationNotificationRead',
          readValue: true,
          touristName: _text(data, ['fullName'], fallback: 'Unnamed tourist'),
          title: 'New Tourist Registration',
          description: 'A tourist account has been registered.',
          timestamp: _timestampFrom(data, [
            'createdAt',
            'registeredAt',
            'registrationDate',
            'createdOn',
          ]),
          isRead: data['registrationNotificationRead'] == true,
        ),
      );
    }

    for (final alert in sosAlerts) {
      final data = alert.data();
      final name = _text(data, [
        'fullName',
        'userName',
      ], fallback: 'Unnamed tourist');
      final status = _text(data, ['status'], fallback: 'Active');
      result.add(
        _AdminNotification(
          id: 'sos-created-${alert.id}',
          kind: _NotificationKind.sosCreated,
          reference: alert.reference,
          readField: 'sosCreatedNotificationRead',
          readValue: true,
          touristName: name,
          title: 'SOS Alert Created',
          description: '$name sent an SOS alert.',
          timestamp: _timestampFrom(data, ['timestamp', 'createdAt']),
          isRead: data['sosCreatedNotificationRead'] == true,
        ),
      );
      final updatedAt = _timestampFrom(data, ['updatedAt']);
      if (updatedAt != null) {
        result.add(
          _AdminNotification(
            id: 'sos-status-${alert.id}',
            kind: _NotificationKind.sosStatus,
            reference: alert.reference,
            readField: 'sosStatusNotificationRead',
            readValue: true,
            touristName: name,
            title: 'SOS Status Updated',
            description: 'SOS alert status changed to $status.',
            timestamp: updatedAt,
            isRead: data['sosStatusNotificationRead'] == true,
          ),
        );
      }
    }

    for (final event in geofenceEvents) {
      final data = event.data();
      final eventType = _normalizeEventType(_text(data, ['eventType']));
      final isDanger = _isDangerEvent(data);
      final entering = eventType == 'ENTER';
      final knownEvent = eventType == 'ENTER' || eventType == 'EXIT';
      final kind = !knownEvent
          ? _NotificationKind.general
          : isDanger
          ? entering
                ? _NotificationKind.dangerEntry
                : _NotificationKind.dangerExit
          : entering
          ? _NotificationKind.safeEntry
          : _NotificationKind.safeExit;
      final zoneName = _text(
        data,
        isDanger
            ? ['dangerZoneName', 'zoneName', 'safeZoneName']
            : ['safeZoneName', 'zoneName'],
        fallback: isDanger ? 'Danger zone' : 'Safe zone',
      );
      final name = _text(data, [
        'userName',
        'touristName',
        'fullName',
      ], fallback: 'Unnamed tourist');
      final notificationRead = data['notificationRead'];
      final read = notificationRead is bool
          ? notificationRead
          : _text(data, ['status']).toLowerCase() == 'read';
      final verb = entering ? 'Entered' : 'Exited';
      result.add(
        _AdminNotification(
          id: 'geofence-${event.id}',
          kind: kind,
          reference: event.reference,
          readField: 'notificationRead',
          readValue: true,
          unreadValue: false,
          touristName: name,
          title: knownEvent
              ? '${isDanger ? 'Danger' : 'Safe'} Zone $verb'
              : 'Geofence Information',
          description: knownEvent
              ? '$name $verb $zoneName.'
              : 'A geofence event was recorded for $zoneName.',
          timestamp: _timestampFrom(data, ['timestamp', 'createdAt']),
          isRead: read,
        ),
      );
    }
    return result;
  }
}

class _DocumentUpdate {
  _DocumentUpdate(this.reference);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, Object?> fields = {};
}

class _AdminNotification {
  const _AdminNotification({
    required this.id,
    required this.kind,
    required this.reference,
    required this.readField,
    required this.readValue,
    required this.touristName,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.isRead,
    this.unreadValue = false,
  });

  final String id;
  final _NotificationKind kind;
  final DocumentReference<Map<String, dynamic>> reference;
  final String readField;
  final Object readValue;
  final Object unreadValue;
  final String touristName;
  final String title;
  final String description;
  final DateTime? timestamp;
  final bool isRead;

  String get category => switch (kind) {
    _NotificationKind.sosCreated || _NotificationKind.sosStatus => 'SOS',
    _NotificationKind.safeEntry ||
    _NotificationKind.safeExit ||
    _NotificationKind.dangerEntry ||
    _NotificationKind.dangerExit ||
    _NotificationKind.general => 'Geofence',
    _NotificationKind.registration => 'Registration',
  };

  String get typeLabel => switch (kind) {
    _NotificationKind.registration => 'Tourist Registration',
    _NotificationKind.sosCreated => 'SOS',
    _NotificationKind.sosStatus => 'SOS Status',
    _NotificationKind.safeEntry => 'Safe Zone Entry',
    _NotificationKind.safeExit => 'Safe Zone Exit',
    _NotificationKind.dangerEntry => 'Danger Zone Entry',
    _NotificationKind.dangerExit => 'Danger Zone Exit',
    _NotificationKind.general => 'General Information',
  };

  IconData get icon => switch (kind) {
    _NotificationKind.registration => Icons.person_add_alt_1_outlined,
    _NotificationKind.sosCreated => Icons.crisis_alert_outlined,
    _NotificationKind.sosStatus => Icons.sync_problem_outlined,
    _NotificationKind.safeEntry => Icons.shield_outlined,
    _NotificationKind.safeExit => Icons.logout_outlined,
    _NotificationKind.dangerEntry => Icons.warning_amber_outlined,
    _NotificationKind.dangerExit => Icons.exit_to_app_outlined,
    _NotificationKind.general => Icons.info_outline,
  };

  Color color(BuildContext context) => switch (kind) {
    _NotificationKind.sosCreated ||
    _NotificationKind.dangerEntry => Theme.of(context).colorScheme.error,
    _NotificationKind.safeEntry => Colors.green,
    _NotificationKind.registration => Colors.blue,
    _NotificationKind.sosStatus => Colors.orange,
    _NotificationKind.safeExit ||
    _NotificationKind.dangerExit => Theme.of(context).colorScheme.outline,
    _NotificationKind.general => Theme.of(context).colorScheme.outline,
  };
}

class _NotificationCounts {
  const _NotificationCounts({
    required this.total,
    required this.unread,
    required this.sos,
    required this.geofence,
    required this.registrations,
  });

  final int total;
  final int unread;
  final int sos;
  final int geofence;
  final int registrations;

  factory _NotificationCounts.from(List<_AdminNotification> items) =>
      _NotificationCounts(
        total: items.length,
        unread: items.where((item) => !item.isRead).length,
        sos: items.where((item) => item.category == 'SOS').length,
        geofence: items.where((item) => item.category == 'Geofence').length,
        registrations: items
            .where((item) => item.category == 'Registration')
            .length,
      );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.counts});

  final _NotificationCounts counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = [
      _SummaryItem(
        'Total Notifications',
        counts.total,
        Icons.notifications_outlined,
        theme.colorScheme.primary,
      ),
      _SummaryItem(
        'Unread',
        counts.unread,
        Icons.mark_email_unread_outlined,
        theme.colorScheme.error,
      ),
      _SummaryItem(
        'SOS',
        counts.sos,
        Icons.crisis_alert_outlined,
        theme.colorScheme.error,
      ),
      _SummaryItem(
        'Geofence',
        counts.geofence,
        Icons.location_on_outlined,
        theme.colorScheme.tertiary,
      ),
      _SummaryItem(
        'Registrations',
        counts.registrations,
        Icons.person_add_alt_1_outlined,
        Colors.blue,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 5
            : constraints.maxWidth >= 650
            ? 3
            : 2;
        final width = (constraints.maxWidth - 8 * (columns - 1)) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(item.icon, color: item.color, size: 21),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.value}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  item.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onToggle});

  final _AdminNotification notification;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = notification.color(context);
    return Card(
      elevation: 0,
      color: notification.isRead
          ? theme.colorScheme.surfaceContainerLow
          : theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.12),
                  foregroundColor: color,
                  child: Icon(notification.icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.typeLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(notification.description),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(notification.isRead ? 'Read' : 'Unread'),
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    notification.isRead
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Tourist: ${notification.touristName}'),
                Text(
                  _formatTimestamp(notification.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: onToggle,
                  icon: Icon(
                    notification.isRead
                        ? Icons.mark_email_unread_outlined
                        : Icons.mark_email_read_outlined,
                  ),
                  label: Text(
                    notification.isRead ? 'Mark as Unread' : 'Mark as Read',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
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

String _text(
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

DateTime? _timestampFrom(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
  }
  return null;
}

String _formatTimestamp(DateTime? dateTime) {
  if (dateTime == null) return 'Timestamp not available';
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
}

String _normalizeEventType(String type) {
  switch (type.toLowerCase()) {
    case 'enter':
    case 'entered':
      return 'ENTER';
    case 'exit':
    case 'exited':
      return 'EXIT';
    default:
      return type.toUpperCase();
  }
}

bool _isDangerEvent(Map<String, dynamic> data) {
  final type = _text(data, ['zoneType', 'type']).toLowerCase();
  return type.contains('danger') ||
      _text(data, ['dangerZoneId', 'dangerZoneName']).isNotEmpty;
}
