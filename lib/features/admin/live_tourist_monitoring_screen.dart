import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const _onlineWindow = Duration(seconds: 30);

class LiveTouristMonitoringScreen extends StatefulWidget {
  const LiveTouristMonitoringScreen({super.key});

  @override
  State<LiveTouristMonitoringScreen> createState() =>
      _LiveTouristMonitoringScreenState();
}

enum _TouristFilter { all, online, offline, safe, danger, activeSos }

class _LiveTouristMonitoringScreenState
    extends State<LiveTouristMonitoringScreen> {
  static const _filters = {
    _TouristFilter.all: 'All',
    _TouristFilter.online: 'Online',
    _TouristFilter.offline: 'Offline',
    _TouristFilter.safe: 'Safe',
    _TouristFilter.danger: 'Danger',
    _TouristFilter.activeSos: 'Active SOS',
  };

  final _searchController = TextEditingController();
  final _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();
  final _touristsStream = FirebaseFirestore.instance
      .collection('tourists')
      .snapshots();
  final _sosStream = FirebaseFirestore.instance
      .collection('sos_alerts')
      .snapshots();

  Timer? _onlineStatusTimer;
  String _searchQuery = '';
  _TouristFilter _selectedFilter = _TouristFilter.all;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _onlineStatusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _onlineStatusTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Tourist Monitoring')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _usersStream,
        builder: (context, usersSnapshot) {
          if (usersSnapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load tourist locations.',
              detail: usersSnapshot.error.toString(),
            );
          }
          if (usersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _touristsStream,
            builder: (context, touristsSnapshot) {
              if (touristsSnapshot.hasError) {
                return _MessageState(
                  icon: Icons.cloud_off_outlined,
                  message: 'Unable to load ESP32 tourist telemetry.',
                  detail: touristsSnapshot.error.toString(),
                );
              }
              if (touristsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _sosStream,
                builder: (context, sosSnapshot) {
                  if (sosSnapshot.hasError) {
                    return _MessageState(
                      icon: Icons.cloud_off_outlined,
                      message: 'Unable to load active SOS alerts.',
                      detail: sosSnapshot.error.toString(),
                    );
                  }
                  if (sosSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return _buildMonitoringView(
                    context,
                    usersSnapshot.data?.docs ?? const [],
                    touristsSnapshot.data?.docs ?? const [],
                    sosSnapshot.data?.docs ?? const [],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMonitoringView(
    BuildContext context,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocuments,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> touristDocuments,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sosDocuments,
  ) {
    final tourists = [
      ...userDocuments.map((document) => _Tourist.fromDocument(document, _now)),
      ...touristDocuments
          .map((document) => _Tourist.fromHardwareDocument(document, _now)),
    ];
    final activeSosDocuments = sosDocuments
        .where((document) => _isActiveSos(document.data()))
        .toList();
    final hardwareActiveTourists = tourists
        .where((tourist) => tourist.isHardware && tourist.sosActive)
        .toList();
    final activeSosUserIds = <String>{};
    for (final alert in activeSosDocuments) {
      final userId = _stringValue(alert.data()['userId']);
      if (userId.isNotEmpty) activeSosUserIds.add(userId);
    }

    final touristsWithCoordinates = tourists
        .where((tourist) => tourist.location != null && (tourist.isHardware ? tourist.gpsValid != false : true))
        .toList();
    final query = _searchQuery.trim().toLowerCase();
    final visibleTourists = touristsWithCoordinates.where((tourist) {
      final hasSos = _hasActiveSos(tourist, activeSosUserIds);
      final matchesSearch =
          query.isEmpty ||
          tourist.fullName.toLowerCase().contains(query) ||
          tourist.documentId.toLowerCase().contains(query) ||
          tourist.email.toLowerCase().contains(query);
      final matchesFilter = switch (_selectedFilter) {
        _TouristFilter.all => true,
        _TouristFilter.online => tourist.isOnline,
        _TouristFilter.offline => !tourist.isOnline,
        _TouristFilter.safe => tourist.safetyStatus == 'safe',
        _TouristFilter.danger => tourist.safetyStatus == 'danger',
        _TouristFilter.activeSos => hasSos,
      };
      return matchesSearch && matchesFilter;
    }).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SummaryGrid(
              total: tourists.length,
              online: tourists.where((tourist) => tourist.isOnline).length,
              offline: tourists.where((tourist) => !tourist.isOnline).length,
              safe: tourists
                  .where((tourist) => tourist.safetyStatus == 'safe')
                  .length,
              danger: tourists
                  .where((tourist) => tourist.safetyStatus == 'danger')
                  .length,
              activeSos: activeSosDocuments.length + hardwareActiveTourists.length,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search),
                  hintText: 'Search by name or email',
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
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filters.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _selectedFilter == entry.key,
                          onSelected: (_) =>
                              setState(() => _selectedFilter = entry.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 520,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildMap(context, visibleTourists, activeSosUserIds),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMap(
    BuildContext context,
    List<_Tourist> tourists,
    Set<String> activeSosUserIds,
  ) {
    final firstLocation = tourists.firstOrNull?.location;
    final initialCenter = firstLocation ?? const LatLng(20, 0);

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            center: initialCenter,
            zoom: firstLocation == null ? 2 : 5,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.hello_test',
            ),
            MarkerLayer(
              markers: tourists.map((tourist) {
                final markerColor = _markerColor(
                  context,
                  tourist,
                  _hasActiveSos(tourist, activeSosUserIds),
                );
                return Marker(
                  point: tourist.location!,
                  width: 48,
                  height: 48,
                  builder: (context) => Tooltip(
                    message: tourist.fullName,
                    child: InkResponse(
                      onTap: () => _showTouristDetails(
                        context,
                        tourist,
                        _hasActiveSos(tourist, activeSosUserIds),
                      ),
                      radius: 28,
                      child: Icon(
                        Icons.location_on,
                        color: markerColor,
                        size: 42,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                '© OpenStreetMap contributors',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        ),
        if (tourists.isEmpty)
          Align(
            alignment: Alignment.center,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_emptyMapMessage(), textAlign: TextAlign.center),
              ),
            ),
          ),
      ],
    );
  }

  String _emptyMapMessage() {
    if (_searchQuery.isNotEmpty || _selectedFilter != _TouristFilter.all) {
      return 'No tourists with coordinates match this search or filter.';
    }
    return 'No tourists with valid coordinates are available.';
  }

  bool _hasActiveSos(_Tourist tourist, Set<String> activeSosUserIds) =>
      tourist.isHardware
          ? tourist.sosActive
          : activeSosUserIds.contains(tourist.documentId) ||
              (tourist.userId.isNotEmpty &&
                  activeSosUserIds.contains(tourist.userId));

  Color _markerColor(
    BuildContext context,
    _Tourist tourist,
    bool hasActiveSos,
  ) {
    if (hasActiveSos || tourist.safetyStatus == 'danger') return Colors.red;
    if (!tourist.isOnline) return Colors.grey;
    if (tourist.safetyStatus == 'warning') return Colors.amber;
    if (tourist.safetyStatus == 'safe') return Colors.green;
    return Theme.of(context).colorScheme.primary;
  }

  void _showTouristDetails(
    BuildContext context,
    _Tourist tourist,
    bool hasActiveSos,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _markerColor(context, tourist, hasActiveSos);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    foregroundColor: statusColor,
                    child: const Icon(Icons.person_pin_circle_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tourist.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Chip(
                    label: Text(tourist.isOnline ? 'Online' : 'Offline'),
                    avatar: Icon(
                      tourist.isOnline ? Icons.circle : Icons.circle_outlined,
                      size: 14,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (tourist.isHardware) ...[
                _DetailRow(
                  icon: Icons.tag_outlined,
                  label: 'Tourist ID',
                  value: tourist.documentId,
                ),
              ],
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: tourist.email,
              ),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: tourist.phone,
              ),
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Latitude',
                value: tourist.latitude?.toStringAsFixed(6) ?? 'Not available',
              ),
              _DetailRow(
                icon: Icons.explore_outlined,
                label: 'Longitude',
                value: tourist.longitude?.toStringAsFixed(6) ?? 'Not available',
              ),
              if (tourist.isHardware) ...[
                _DetailRow(
                  icon: Icons.gps_fixed_outlined,
                  label: 'GPS status',
                  value: tourist.gpsValid == null
                      ? 'Unknown'
                      : tourist.gpsValid!
                          ? 'Valid'
                          : 'Invalid',
                ),
              ],
              _DetailRow(
                icon: Icons.schedule_outlined,
                label: 'Last Updated',
                value: _formatDateTime(tourist.lastUpdated),
              ),
              if (tourist.isHardware) ...[
                _DetailRow(
                  icon: Icons.wifi_tethering_outlined,
                  label: 'Online/offline status',
                  value: tourist.isOnline ? 'Online' : 'Offline',
                ),
                _DetailRow(
                  icon: Icons.crisis_alert_outlined,
                  label: 'SOS status',
                  value: tourist.sosActive ? 'Active' : 'Resolved',
                ),
                _DetailRow(
                  icon: Icons.format_list_numbered_outlined,
                  label: 'Sequence',
                  value: tourist.sequence?.toString() ?? 'Not available',
                ),
                _DetailRow(
                  icon: Icons.signal_cellular_alt_2_bar_outlined,
                  label: 'RSSI',
                  value: tourist.rssi?.toString() ?? 'Not available',
                ),
              ] else ...[
                _DetailRow(
                  icon: Icons.shield_outlined,
                  label: 'Current Safe Zone',
                  value: tourist.currentSafeZone,
                ),
                _DetailRow(
                  icon: Icons.warning_amber_outlined,
                  label: 'Current Danger Zone',
                  value: tourist.currentDangerZone,
                ),
                _DetailRow(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Current Safety Status',
                  value: tourist.safetyStatusLabel,
                  valueColor: statusColor,
                ),
                _DetailRow(
                  icon: Icons.manage_accounts_outlined,
                  label: 'Account Status',
                  value: tourist.accountStatus,
                  valueColor: colorScheme.onSurface,
                ),
              ],
              if (hasActiveSos)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.crisis_alert, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        'Active SOS alert',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.total,
    required this.online,
    required this.offline,
    required this.safe,
    required this.danger,
    required this.activeSos,
  });

  final int total;
  final int online;
  final int offline;
  final int safe;
  final int danger;
  final int activeSos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tiles = [
      _SummaryTileData(
        'Total Tourists',
        total,
        Icons.people_alt_outlined,
        colorScheme.primary,
      ),
      _SummaryTileData('Online', online, Icons.wifi_tethering, Colors.green),
      _SummaryTileData(
        'Offline',
        offline,
        Icons.wifi_off_outlined,
        Colors.grey,
      ),
      _SummaryTileData('Safe', safe, Icons.shield_outlined, Colors.green),
      _SummaryTileData(
        'Danger',
        danger,
        Icons.warning_amber_outlined,
        Colors.red,
      ),
      _SummaryTileData(
        'Active SOS',
        activeSos,
        Icons.crisis_alert_outlined,
        colorScheme.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 6
            : constraints.maxWidth >= 620
            ? 3
            : 2;
        const spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles
              .map(
                (tile) => SizedBox(
                  width: width,
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(tile.icon, size: 20, color: tile.color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${tile.count}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  tile.label,
                                  maxLines: 1,
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

class _SummaryTileData {
  const _SummaryTileData(this.label, this.count, this.icon, this.color);

  final String label;
  final int count;
  final IconData icon;
  final Color color;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: valueColor == null ? null : TextStyle(color: valueColor),
            ),
          ),
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

class _Tourist {
  const _Tourist({
    required this.documentId,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    required this.isOnline,
    required this.currentSafeZone,
    required this.currentDangerZone,
    required this.safetyStatus,
    required this.accountStatus,
    required this.source,
    this.gpsValid,
    this.sosActive = false,
    this.sequence,
    this.rssi,
  });

  final String documentId;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final double? latitude;
  final double? longitude;
  final DateTime? lastUpdated;
  final bool isOnline;
  final String currentSafeZone;
  final String currentDangerZone;
  final String safetyStatus;
  final String accountStatus;
  final String source;
  final bool? gpsValid;
  final bool sosActive;
  final num? sequence;
  final num? rssi;

  bool get isHardware => source == 'hardware';

  LatLng? get location {
    if (latitude == null || longitude == null) return null;
    return LatLng(latitude!, longitude!);
  }

  String get safetyStatusLabel =>
      safetyStatus.isEmpty ? 'Not available' : safetyStatus;

  factory _Tourist.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    DateTime now,
  ) {
    final data = document.data();
    final latitude = _coordinate(data['latitude'], min: -90, max: 90);
    final longitude = _coordinate(data['longitude'], min: -180, max: 180);
    final lastUpdated = _dateTime(data['lastUpdated']);
    final age = lastUpdated == null ? null : now.difference(lastUpdated);
    final status = _stringValue(data['currentSafetyStatus']).toLowerCase();

    return _Tourist(
      documentId: document.id,
      userId: _stringValue(data['userId']),
      fullName: _stringValue(data['fullName'], fallback: 'Unnamed tourist'),
      email: _stringValue(data['email'], fallback: 'Not provided'),
      phone: _stringValue(data['phone'], fallback: 'Not provided'),
      latitude: latitude,
      longitude: longitude,
      lastUpdated: lastUpdated,
      isOnline: age != null && age >= Duration.zero && age <= _onlineWindow,
      currentSafeZone: _stringValue(
        data['currentSafeZone'],
        fallback: 'Not available',
      ),
      currentDangerZone: _stringValue(
        data['currentDangerZone'],
        fallback: 'Not available',
      ),
      safetyStatus: status,
      accountStatus: _stringValue(
        data['accountStatus'],
        fallback: 'Not available',
      ),
      source: 'user',
    );
  }

  factory _Tourist.fromHardwareDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
    DateTime now,
  ) {
    final data = document.data();
    final uid = _stringValue(data['uid'], fallback: document.id);
    final latitude = _coordinate(data['latitude'], min: -90, max: 90);
    final longitude = _coordinate(data['longitude'], min: -180, max: 180);
    final lastUpdated = _dateTime(data['lastUpdated']);
    final age = lastUpdated == null ? null : now.difference(lastUpdated);

    return _Tourist(
      documentId: document.id,
      userId: uid,
      fullName: uid,
      email: 'Not available',
      phone: 'Not available',
      latitude: latitude,
      longitude: longitude,
      lastUpdated: lastUpdated,
      isOnline: age != null && age >= Duration.zero && age <= _onlineWindow,
      currentSafeZone: 'Unknown',
      currentDangerZone: 'Unknown',
      safetyStatus: 'Unknown',
      accountStatus: 'Unknown',
      source: 'hardware',
      gpsValid: data['gpsValid'] is bool ? data['gpsValid'] as bool : null,
      sosActive: data['sosActive'] == true,
      sequence: data['sequence'] is num ? data['sequence'] as num : null,
      rssi: data['rssi'] is num ? data['rssi'] as num : null,
    );
  }
}

bool _isActiveSos(Map<String, dynamic> data) {
  final status = _stringValue(data['status']).toLowerCase();
  return data['resolved'] != true && status != 'resolved';
}

String _stringValue(Object? value, {String fallback = ''}) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}

double? _coordinate(Object? value, {required double min, required double max}) {
  final coordinate = value is num
      ? value.toDouble()
      : double.tryParse('$value');
  if (coordinate == null ||
      !coordinate.isFinite ||
      coordinate < min ||
      coordinate > max) {
    return null;
  }
  return coordinate;
}

DateTime? _dateTime(Object? value) {
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

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Not available';
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}:${twoDigits(value.second)}';
}
