import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class TouristLocationSyncService {
  TouristLocationSyncService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _distanceThresholdMeters = 10.0;
  static const _retryInterval = Duration(seconds: 10);

  final FirebaseFirestore _firestore;

  StreamSubscription<Position>? _positionSubscription;
  Timer? _retryTimer;
  String? _userId;
  Position? _latestPosition;
  Position? _lastUploadedPosition;
  Position? _pendingPosition;
  Map<String, Object?>? _safetyFields;
  bool _checkingLocation = false;
  bool _writingLocation = false;
  bool _writeFailed = false;
  String? _lastLocationIssue;
  int _generation = 0;

  Future<void> startTracking(String userId) async {
    if (userId.isEmpty) {
      debugPrint('Location tracking not started: authenticated UID is empty.');
      return;
    }
    if (_userId == userId && _retryTimer != null) {
      debugPrint('Location tracking is already active for user $userId.');
      return;
    }

    await stopTracking(markOffline: true);
    _userId = userId;
    _lastUploadedPosition = null;
    final generation = ++_generation;
    debugPrint('Starting location tracking for user $userId.');

    _retryTimer = Timer.periodic(_retryInterval, (_) {
      if (_userId != userId || generation != _generation) return;
      unawaited(
        _ensureLocationTracking(
          requestPermission: false,
          generation: generation,
        ),
      );
      if (_writeFailed && _latestPosition != null) {
        _queuePosition(_latestPosition!);
      }
    });

    unawaited(_setOnlineStatus(userId, true));
    await _ensureLocationTracking(
      requestPermission: true,
      generation: generation,
    );
  }

  Future<void> stopTracking({bool markOffline = false}) async {
    final userId = _userId;
    _userId = null;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    _latestPosition = null;
    _lastUploadedPosition = null;
    _pendingPosition = null;
    _writeFailed = false;
    _safetyFields = null;
    _lastLocationIssue = null;

    if (markOffline && userId != null) {
      await _setOnlineStatus(userId, false);
    }
  }

  void updateSafetyState({
    required String? currentSafeZone,
    required String currentSafetyStatus,
  }) {
    final fields = <String, Object?>{
      'currentSafeZone': currentSafeZone,
      'currentDangerZone': null,
      'currentSafetyStatus': currentSafetyStatus,
    };
    if (mapEquals(_safetyFields, fields)) return;
    _safetyFields = fields;

    final userId = _userId;
    if (userId != null) {
      unawaited(
        _firestore
            .collection('users')
            .doc(userId)
            .set(fields, SetOptions(merge: true))
            .catchError((Object error) {
              debugPrint('Unable to update tourist safety status: $error');
            }),
      );
    }
  }

  Future<void> _ensureLocationTracking({
    required bool requestPermission,
    required int generation,
  }) async {
    final userId = _userId;
    if (userId == null ||
        generation != _generation ||
        _positionSubscription != null ||
        _checkingLocation) {
      return;
    }

    _checkingLocation = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _reportLocationIssue('GPS is disabled; location tracking will retry.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          generation != _generation ||
          _userId == null) {
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _reportLocationIssue(
            'Location permission denied; tracking will retry when permission is granted.',
          );
        }
        return;
      }

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (position) {
              _lastLocationIssue = null;
              debugPrint('Location tracking started for user $userId.');
              _queuePosition(position);
            },
            onError: (Object error) {
              _reportLocationIssue('Tourist location stream failed: $error');
              _positionSubscription = null;
            },
            onDone: () => _positionSubscription = null,
            cancelOnError: true,
          );
      _lastLocationIssue = null;
      debugPrint('Location tracking started for user $userId.');
    } catch (error) {
      _reportLocationIssue('Unable to start tourist location tracking: $error');
    } finally {
      _checkingLocation = false;
    }
  }

  void _queuePosition(Position position) {
    if (_userId == null) return;
    _latestPosition = position;
    debugPrint('Location: ${position.latitude}, ${position.longitude}');
    if (!_hasSignificantChange(position)) return;

    if (_writingLocation) {
      _pendingPosition = position;
      return;
    }
    unawaited(_writeLocation(position));
  }

  bool _hasSignificantChange(Position position) {
    final previous = _lastUploadedPosition;
    if (previous == null) return true;
    return Geolocator.distanceBetween(
          previous.latitude,
          previous.longitude,
          position.latitude,
          position.longitude,
        ) >
        _distanceThresholdMeters;
  }

  Future<void> _writeLocation(Position position) async {
    final userId = _userId;
    if (userId == null) return;

    final generation = _generation;
    _writingLocation = true;
    try {
      debugPrint('Updating Firestore users/$userId...');
      await _firestore.collection('users').doc(userId).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'lastUpdated': FieldValue.serverTimestamp(),
        'isOnline': true,
        ...?_safetyFields,
      }, SetOptions(merge: true));
      if (generation == _generation) {
        _lastUploadedPosition = position;
        _writeFailed = false;
        debugPrint('Firestore updated successfully for users/$userId.');
      }
    } catch (error) {
      debugPrint('Firestore update failed for users/$userId: $error');
      if (generation == _generation) _writeFailed = true;
    } finally {
      _writingLocation = false;
      final pending = _pendingPosition;
      _pendingPosition = null;
      if (pending != null &&
          _userId != null &&
          _hasSignificantChange(pending)) {
        _queuePosition(pending);
      }
    }
  }

  Future<void> _setOnlineStatus(String userId, bool isOnline) async {
    try {
      debugPrint('Updating Firestore online status for users/$userId...');
      await _firestore.collection('users').doc(userId).set({
        'isOnline': isOnline,
      }, SetOptions(merge: true));
      debugPrint(
        'Firestore online status updated for users/$userId: $isOnline.',
      );
    } catch (error) {
      debugPrint('Unable to update tourist online status: $error');
    }
  }

  void _reportLocationIssue(String message) {
    if (_lastLocationIssue == message) return;
    _lastLocationIssue = message;
    debugPrint(message);
  }
}
