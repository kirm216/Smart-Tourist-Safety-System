import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../auth/auth_service.dart';
import 'tourist_location_sync_service.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key, required this.locationSyncService});

  final TouristLocationSyncService locationSyncService;

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<Position>? _positionStreamSubscription;
  final Map<String, bool> _zoneMembership = {};

  bool _isLoading = true;
  bool _permissionDenied = false;
  String? _errorMessage;
  String? _safeZoneError;
  String? _dangerZoneError;
  Position? _position;
  final List<SafeZone> _safeZones = [];
  final List<DangerZone> _dangerZones = [];
  bool _dangerZonesAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSafeZones();
    _loadDangerZones();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _permissionDenied = true;
        });
        return;
      }

      _startPositionStream();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _startPositionStream() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _position = position;
            });

            _checkSafetyZones(position);
          },
          onError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorMessage = error.toString();
            });
          },
        );
  }

  Future<void> _loadSafeZones() async {
    try {
      final snapshot = await _firestore.collection('safe_zones').get();
      final zones = snapshot.docs
          .map((doc) {
            final data = doc.data();
            return SafeZone(
              id: doc.id,
              name: (data['name'] as String?)?.trim() ?? 'Unnamed zone',
              description: (data['description'] as String?)?.trim() ?? '',
              type: (data['type'] as String?)?.trim() ?? 'Tourist Help',
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
              radius: (data['radius'] as num?)?.toDouble() ?? 0,
            );
          })
          .where((zone) => zone.latitude != 0.0 && zone.longitude != 0.0)
          .toList();

      if (!mounted) return;
      setState(() {
        _safeZones.clear();
        _safeZones.addAll(zones);
      });

      if (_position != null) {
        _checkSafetyZones(_position!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _safeZoneError = error.toString();
      });
    }
  }

  Future<void> _loadDangerZones() async {
    try {
      final snapshot = await _firestore.collection('danger_zones').get();
      final zones = snapshot.docs
          .where((doc) => doc.data()['status'] == 'enabled')
          .map((doc) {
            final data = doc.data();
            return DangerZone(
              name: (data['name'] as String?)?.trim().isNotEmpty == true
                  ? (data['name'] as String).trim()
                  : 'Unnamed zone',
              latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
              longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
              radius: (data['radius'] as num?)?.toDouble() ?? 0,
            );
          })
          .where(
            (zone) =>
                zone.latitude.isFinite &&
                zone.longitude.isFinite &&
                zone.radius.isFinite &&
                zone.latitude >= -90 &&
                zone.latitude <= 90 &&
                zone.longitude >= -180 &&
                zone.longitude <= 180 &&
                zone.radius > 0,
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _dangerZones
          ..clear()
          ..addAll(zones);
        _dangerZonesAvailable = true;
        _dangerZoneError = null;
      });
      if (_position != null) _checkSafetyZones(_position!);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _dangerZonesAvailable = false;
        _dangerZoneError = error.toString();
      });
      if (_position != null) _checkSafetyZones(_position!);
    }
  }

  void _checkSafetyZones(Position position) {
    SafeZone? currentSafeZone;
    for (final zone in _safeZones) {
      final isInside =
          Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            zone.latitude,
            zone.longitude,
          ) <=
          zone.radius;

      if (isInside) currentSafeZone ??= zone;

      final wasInside = _zoneMembership[zone.id] ?? false;
      if (isInside && !wasInside) {
        _zoneMembership[zone.id] = true;
        _saveGeoFenceAlert(zone, position, 'ENTER');
        _showGeoFenceSnackBar('You entered ${zone.name}');
      } else if (!isInside && wasInside) {
        _zoneMembership[zone.id] = false;
        _saveGeoFenceAlert(zone, position, 'EXIT');
        _showGeoFenceSnackBar('You left ${zone.name}');
      }
    }

    DangerZone? currentDangerZone;
    if (_dangerZonesAvailable) {
      for (final zone in _dangerZones) {
        final isInside =
            Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              zone.latitude,
              zone.longitude,
            ) <=
            zone.radius;
        if (isInside) {
          currentDangerZone = zone;
          break;
        }
      }
    }

    final safetyStatus = !_dangerZonesAvailable
        ? 'unknown'
        : currentDangerZone != null
        ? 'danger'
        : currentSafeZone != null
        ? 'safe'
        : 'unknown';
    widget.locationSyncService.updateSafetyState(
      currentSafeZone: safetyStatus == 'safe' ? currentSafeZone?.name : null,
      currentDangerZone: currentDangerZone?.name,
      currentSafetyStatus: safetyStatus,
    );
  }

  Future<void> _saveGeoFenceAlert(
    SafeZone zone,
    Position position,
    String eventType,
  ) async {
    final user = AuthService().currentUser;
    if (user == null) return;

    final alertData = {
      'userId': user.uid,
      'userName': user.displayName ?? '',
      'userEmail': user.email ?? '',
      'safeZoneId': zone.id,
      'safeZoneName': zone.name,
      'eventType': eventType,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'unread',
    };

    try {
      await _firestore.collection('geo_fence_alerts').add(alertData);
    } catch (_) {
      // Ignore failures to preserve map experience; alerts are best-effort.
    }
  }

  void _showGeoFenceSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maps')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionDenied) {
      return _buildPermissionDenied(context);
    }

    if (_errorMessage != null) {
      return _buildError(context, _errorMessage!);
    }

    if (_position == null) {
      return _buildError(context, 'Unable to determine your current location.');
    }

    final currentLocation = LatLng(_position!.latitude, _position!.longitude);

    return Column(
      children: [
        if (_safeZoneError != null || _dangerZoneError != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(12),
            child: Text(
              [
                if (_safeZoneError != null)
                  'Unable to load safe zones: $_safeZoneError',
                if (_dangerZoneError != null)
                  'Unable to load danger zones: $_dangerZoneError',
              ].join('\n'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        Expanded(
          child: FlutterMap(
            options: MapOptions(center: currentLocation, zoom: 15, maxZoom: 18),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hello_test',
              ),
              if (_safeZones.isNotEmpty)
                CircleLayer(
                  circles: _safeZones.map((zone) {
                    final color = zone.markerColor.withAlpha(
                      (0.25 * 255).round(),
                    );
                    return CircleMarker(
                      point: LatLng(zone.latitude, zone.longitude),
                      radius: zone.radius,
                      useRadiusInMeter: true,
                      color: color,
                      borderColor: zone.markerColor,
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),
              if (_dangerZones.isNotEmpty)
                CircleLayer(
                  circles: _dangerZones.map((zone) {
                    final dangerColor = Theme.of(context).colorScheme.error;
                    return CircleMarker(
                      point: LatLng(zone.latitude, zone.longitude),
                      radius: zone.radius,
                      useRadiusInMeter: true,
                      color: dangerColor.withAlpha((0.25 * 255).round()),
                      borderColor: dangerColor,
                      borderStrokeWidth: 3,
                    );
                  }).toList(),
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation,
                    width: 60,
                    height: 60,
                    builder: (context) {
                      return const Icon(
                        Icons.location_pin,
                        color: Colors.redAccent,
                        size: 48,
                      );
                    },
                  ),
                  ..._safeZones.map((zone) {
                    return Marker(
                      point: LatLng(zone.latitude, zone.longitude),
                      width: 48,
                      height: 48,
                      builder: (context) {
                        return GestureDetector(
                          onTap: () => _showZoneDetails(context, zone),
                          child: Icon(
                            Icons.location_on,
                            color: zone.markerColor,
                            size: 40,
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Location permission required',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please allow location access so the map can center on your current position.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: Geolocator.openAppSettings,
              child: const Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to show location',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  void _showZoneDetails(BuildContext context, SafeZone zone) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                zone.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                zone.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.circle, color: zone.markerColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Radius: ${zone.radius.toStringAsFixed(0)}m',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SafeZone {
  SafeZone({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final double latitude;
  final double longitude;
  final double radius;

  Color get markerColor {
    switch (type.toLowerCase()) {
      case 'police':
        return Colors.blue;
      case 'hospital':
        return Colors.green;
      case 'tourist help':
      case 'tourist_help':
      case 'tourist':
        return Colors.orange;
      default:
        return Colors.orange;
    }
  }
}

class DangerZone {
  const DangerZone({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  final String name;
  final double latitude;
  final double longitude;
  final double radius;
}
