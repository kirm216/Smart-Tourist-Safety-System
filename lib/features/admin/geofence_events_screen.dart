import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'geofence_event_details_screen.dart';

class GeofenceEventsScreen extends StatefulWidget {
  const GeofenceEventsScreen({super.key});

  @override
  State<GeofenceEventsScreen> createState() => _GeofenceEventsScreenState();
}

enum _EventSort { newest, oldest, touristName }

class _GeofenceEventsScreenState extends State<GeofenceEventsScreen> {
  static const _filters = ['All', 'ENTER', 'EXIT', 'Read', 'Unread'];
  static final _eventsStream = FirebaseFirestore.instance
      .collection('geo_fence_alerts')
      .snapshots();

  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  _EventSort _sort = _EventSort.newest;

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
      appBar: AppBar(title: const Text('Geo-fence Events')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load geofence events.',
              detail: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allEvents = snapshot.data?.docs ?? [];
          final entryCount = allEvents
              .where((event) => _eventType(event.data()) == 'ENTER')
              .length;
          final exitCount = allEvents
              .where((event) => _eventType(event.data()) == 'EXIT')
              .length;
          final readCount = allEvents
              .where((event) => _eventStatus(event.data()) == 'Read')
              .length;
          final unreadCount = allEvents.length - readCount;
          final query = _searchQuery.trim().toLowerCase();
          final events = allEvents.where((event) {
            final data = event.data();
            final name = _touristName(data).toLowerCase();
            final email = _touristEmail(data).toLowerCase();
            final zoneName = _zoneName(data).toLowerCase();
            final matchesSearch =
                query.isEmpty ||
                name.contains(query) ||
                email.contains(query) ||
                zoneName.contains(query);
            final filterValue = _selectedFilter.toLowerCase();
            final matchesFilter =
                _selectedFilter == 'All' ||
                _eventType(data) == filterValue.toUpperCase() ||
                _eventStatus(data).toLowerCase() == filterValue;
            return matchesSearch && matchesFilter;
          }).toList()..sort(_compareEvents);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _EventControls(
                  controller: _searchController,
                  filters: _filters,
                  selectedFilter: _selectedFilter,
                  sort: _sort,
                  totalCount: allEvents.length,
                  entryCount: entryCount,
                  exitCount: exitCount,
                  readCount: readCount,
                  unreadCount: unreadCount,
                  onSearchChanged: (value) =>
                      setState(() => _searchQuery = value),
                  onFilterChanged: (value) =>
                      setState(() => _selectedFilter = value),
                  onSortChanged: (value) => setState(() => _sort = value),
                ),
              ),
              if (events.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.location_searching_outlined,
                    message: allEvents.isEmpty
                        ? 'No geofence events found.'
                        : 'No events match these filters.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return _GeofenceEventCard(
                        event: event,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                GeofenceEventDetailsScreen(event: event),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  int _compareEvents(
    QueryDocumentSnapshot<Map<String, dynamic>> left,
    QueryDocumentSnapshot<Map<String, dynamic>> right,
  ) {
    final nameComparison = _touristName(
      left.data(),
    ).toLowerCase().compareTo(_touristName(right.data()).toLowerCase());
    switch (_sort) {
      case _EventSort.newest:
        final timeComparison = _compareTimestamps(
          _eventTimestamp(left.data()),
          _eventTimestamp(right.data()),
          newestFirst: true,
        );
        return timeComparison == 0 ? nameComparison : timeComparison;
      case _EventSort.oldest:
        final timeComparison = _compareTimestamps(
          _eventTimestamp(left.data()),
          _eventTimestamp(right.data()),
          newestFirst: false,
        );
        return timeComparison == 0 ? nameComparison : timeComparison;
      case _EventSort.touristName:
        return nameComparison;
    }
  }
}

class _EventControls extends StatelessWidget {
  const _EventControls({
    required this.controller,
    required this.filters,
    required this.selectedFilter,
    required this.sort,
    required this.totalCount,
    required this.entryCount,
    required this.exitCount,
    required this.readCount,
    required this.unreadCount,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final List<String> filters;
  final String selectedFilter;
  final _EventSort sort;
  final int totalCount;
  final int entryCount;
  final int exitCount;
  final int readCount;
  final int unreadCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_EventSort> onSortChanged;

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
              hintText: 'Search tourist or zone',
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
          _FilterChips(
            label: 'Filter Events',
            options: filters,
            selected: selectedFilter,
            onSelected: onFilterChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Sort', style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<_EventSort>(
                  initialValue: sort,
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
                    DropdownMenuItem(
                      value: _EventSort.newest,
                      child: Text('Newest'),
                    ),
                    DropdownMenuItem(
                      value: _EventSort.oldest,
                      child: Text('Oldest'),
                    ),
                    DropdownMenuItem(
                      value: _EventSort.touristName,
                      child: Text('Tourist Name'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _EventStatTile(
                    width: tileWidth,
                    label: 'Total Events',
                    count: totalCount,
                    color: theme.colorScheme.primary,
                  ),
                  _EventStatTile(
                    width: tileWidth,
                    label: 'ENTER Events',
                    count: entryCount,
                    color: theme.colorScheme.tertiary,
                  ),
                  _EventStatTile(
                    width: tileWidth,
                    label: 'EXIT Events',
                    count: exitCount,
                    color: theme.colorScheme.secondary,
                  ),
                  _EventStatTile(
                    width: tileWidth,
                    label: 'Read Events',
                    count: readCount,
                    color: theme.colorScheme.primary,
                  ),
                  _EventStatTile(
                    width: tileWidth,
                    label: 'Unread Events',
                    count: unreadCount,
                    color: theme.colorScheme.error,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option),
                  selected: selected == option,
                  onSelected: (_) => onSelected(option),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _EventStatTile extends StatelessWidget {
  const _EventStatTile({
    required this.width,
    required this.label,
    required this.count,
    required this.color,
  });

  final double width;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      label,
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
    );
  }
}

class _GeofenceEventCard extends StatelessWidget {
  const _GeofenceEventCard({required this.event, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = event.data();
    final zoneType = _zoneType(data);
    final eventType = _eventType(data);
    final zoneColor = _zoneColor(context, zoneType);
    final eventColor = theme.colorScheme.primary;
    final isEntered = eventType == 'ENTER';

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
                      _touristName(data),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Chip(
                    avatar: Icon(
                      isEntered ? Icons.login : Icons.logout,
                      size: 18,
                      color: isEntered
                          ? theme.colorScheme.onPrimary
                          : eventColor,
                    ),
                    label: Text(eventType),
                    labelStyle: TextStyle(
                      color: isEntered
                          ? theme.colorScheme.onPrimary
                          : eventColor,
                    ),
                    backgroundColor: isEntered
                        ? eventColor
                        : theme.colorScheme.surface,
                    side: BorderSide(
                      color: eventColor,
                      width: isEntered ? 0 : 1,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text('$zoneType Zone'),
                    backgroundColor: zoneColor.withValues(alpha: 0.12),
                    side: BorderSide(color: zoneColor),
                    labelStyle: TextStyle(color: zoneColor),
                  ),
                  Chip(
                    avatar: Icon(
                      _eventStatus(data) == 'Read'
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 18,
                    ),
                    label: Text(_eventStatus(data)),
                  ),
                ],
              ),
              _EventDetailRow(
                icon: Icons.email_outlined,
                label: 'User Email',
                value: _displayValue(_touristEmail(data)),
              ),
              _EventDetailRow(
                icon: Icons.place_outlined,
                label: 'Safe Zone Name',
                value: _zoneName(data),
              ),
              _EventDetailRow(
                icon: Icons.schedule_outlined,
                label: 'Date & Time',
                value: _formatTimestamp(data['timestamp']),
              ),
              _EventDetailRow(
                icon: Icons.location_on_outlined,
                label: 'Latitude',
                value: _numberValue(data['latitude']),
              ),
              _EventDetailRow(
                icon: Icons.explore_outlined,
                label: 'Longitude',
                value: _numberValue(data['longitude']),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailRow extends StatelessWidget {
  const _EventDetailRow({
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

String _touristName(Map<String, dynamic> data) =>
    _firstText(data, ['touristName', 'userName'], fallback: 'Unknown tourist');

String _touristEmail(Map<String, dynamic> data) =>
    _firstText(data, ['touristEmail', 'userEmail']);

String _zoneName(Map<String, dynamic> data) =>
    _firstText(data, ['zoneName', 'safeZoneName'], fallback: 'Unknown zone');

String _zoneType(Map<String, dynamic> data) {
  final type = _firstText(data, ['zoneType']);
  switch (type.toLowerCase()) {
    case 'safe':
      return 'Safe';
    case 'danger':
      return 'Danger';
    default:
      return type.isEmpty ? 'Unknown' : type;
  }
}

String _eventType(Map<String, dynamic> data) {
  final type = _firstText(data, ['eventType']).toLowerCase();
  switch (type) {
    case 'enter':
    case 'entered':
      return 'ENTER';
    case 'exit':
    case 'exited':
      return 'EXIT';
    default:
      return type.isEmpty ? 'Unknown' : type.toUpperCase();
  }
}

String _eventStatus(Map<String, dynamic> data) {
  final status = _firstText(data, ['status']).toLowerCase();
  return status == 'read' ? 'Read' : 'Unread';
}

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

String _numberValue(Object? value) {
  if (value is num) return value.toString();
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return 'Not provided';
}

DateTime? _eventTimestamp(Map<String, dynamic> data) {
  final value = data['timestamp'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
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

int _compareTimestamps(
  DateTime? left,
  DateTime? right, {
  required bool newestFirst,
}) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return newestFirst ? right.compareTo(left) : left.compareTo(right);
}
