import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

import '../auth/auth_service.dart';
import '../profile/profile_screen.dart';
import 'maps_screen.dart';
import 'tourist_feedback_screen.dart';
import 'tourist_location_sync_service.dart';

class TouristDashboard extends StatefulWidget {
  const TouristDashboard({super.key});

  @override
  State<TouristDashboard> createState() => _TouristDashboardState();
}

class _TouristDashboardState extends State<TouristDashboard> {
  final _locationSyncService = TouristLocationSyncService();
  final _speechToText = SpeechToText();
  late final Stream<DocumentSnapshot<Map<String, dynamic>>>?
  _safetyStatusStream;
  late final Future<bool> _speechInitialization;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isStartingVoiceSOS = false;
  bool _voiceSosTriggered = false;
  String? _speechErrorMessage;

  @override
  void initState() {
    super.initState();
    _speechInitialization = _initializeSpeechRecognition();
    final user = AuthService().currentUser;
    _safetyStatusStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();
    if (user != null) {
      debugPrint('Tourist Dashboard opened for user ${user.uid}.');
      unawaited(_locationSyncService.startTracking(user.uid));
    } else {
      debugPrint(
        'Tourist location tracking not started: no authenticated user.',
      );
    }
  }

  @override
  void dispose() {
    unawaited(_cancelSpeechRecognition());
    unawaited(_locationSyncService.stopTracking(markOffline: true));
    super.dispose();
  }

  Future<bool> _initializeSpeechRecognition() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
      return available;
    } catch (error) {
      debugPrint('Voice SOS speech recognition initialization failed: $error');
      if (mounted) {
        setState(() {
          _speechErrorMessage =
              'Voice SOS is unavailable. Please check microphone permission and try again.';
        });
      }
      return false;
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      _isListening = status == 'listening';
      if (_isListening || status == 'notListening' || status == 'done') {
        _isStartingVoiceSOS = false;
      }
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    final wasActive = _isListening || _isStartingVoiceSOS;
    final permissionDenied = error.errorMsg.toLowerCase().contains(
      'permission',
    );
    final message = permissionDenied
        ? 'Microphone permission was denied. Please allow microphone access to use Voice SOS.'
        : 'Voice SOS is unavailable right now. Please try again.';
    debugPrint('Voice SOS speech recognition error: ${error.errorMsg}');
    if (!mounted) return;
    setState(() {
      _speechErrorMessage = message;
      _isListening = false;
      _isStartingVoiceSOS = false;
    });
    if (wasActive) _showSnackBar(context, message);
  }

  Future<void> _startVoiceSOS() async {
    if (_isListening || _isStartingVoiceSOS || _speechToText.isListening) {
      return;
    }

    setState(() {
      _isStartingVoiceSOS = true;
      _speechErrorMessage = null;
    });

    try {
      _speechAvailable = await _speechInitialization;
      if (!mounted) return;
      if (!_speechAvailable) {
        setState(() {
          _isStartingVoiceSOS = false;
        });
        _showSnackBar(
          context,
          _speechErrorMessage ??
              'Voice SOS is unavailable. Please check microphone permission and try again.',
        );
        return;
      }

      _voiceSosTriggered = false;
      setState(() {
        _isListening = true;
      });
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      debugPrint('Unable to start Voice SOS speech recognition: $error');
      if (!mounted) return;
      final message =
          'Voice SOS could not start. Please check microphone permission and try again.';
      setState(() {
        _isListening = false;
        _isStartingVoiceSOS = false;
        _speechErrorMessage = message;
      });
      _showSnackBar(context, message);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (_voiceSosTriggered ||
        !RegExp(
          r'\b(?:sos|help|emergency)\b',
          caseSensitive: false,
        ).hasMatch(result.recognizedWords)) {
      return;
    }

    _voiceSosTriggered = true;
    if (mounted) {
      setState(() {
        _isListening = false;
        _isStartingVoiceSOS = false;
      });
    }
    unawaited(_confirmVoiceSOS());
  }

  Future<void> _confirmVoiceSOS() async {
    try {
      await _speechToText.cancel();
    } catch (error) {
      debugPrint('Unable to cancel Voice SOS listening: $error');
      if (mounted) {
        _showSnackBar(
          context,
          'Voice listening could not be stopped automatically.',
        );
      }
    }
    if (mounted) await _confirmAndSendSOS(context);
  }

  Future<void> _cancelSpeechRecognition() async {
    try {
      await _speechToText.cancel();
    } catch (error) {
      debugPrint('Unable to stop Voice SOS during dashboard disposal: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email ?? '';
    final welcomeMessage = displayName?.isNotEmpty == true
        ? 'Welcome back, $displayName'
        : 'Welcome to Smart Tourist Safety';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sign out',
            onPressed: () => _confirmSignOut(context, authService),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            welcomeMessage,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            email.isNotEmpty
                                ? 'Logged in as $email'
                                : 'Stay safe with quick access to emergency features and travel guidance.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSafetyStatusCard(context),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth < 720
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 24) / 2;
                      return Wrap(
                        runSpacing: 16,
                        spacing: 16,
                        children: [
                          _ActionCard(
                            title: 'SOS',
                            subtitle: 'Emergency alert',
                            icon: Icons.warning_amber_outlined,
                            color: Theme.of(context).colorScheme.errorContainer,
                            onTap: () => _confirmAndSendSOS(context),
                            width: cardWidth,
                          ),
                          _ActionCard(
                            title: 'Maps',
                            subtitle: 'Find nearby routes',
                            icon: Icons.map_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            onTap: () => _openMaps(context),
                            width: cardWidth,
                          ),
                          _ActionCard(
                            title: 'Profile',
                            subtitle: 'Manage account',
                            icon: Icons.person_outline,
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            onTap: () => _openProfile(context),
                            width: cardWidth,
                          ),
                          _ActionCard(
                            title: 'Feedback',
                            subtitle: 'Share your experience',
                            icon: Icons.rate_review_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            onTap: () => _openFeedback(context),
                            width: cardWidth,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Travel safety tips',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Keep your location sharing on and stay aware of nearby safe spaces. Use SOS when you need immediate assistance.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 60,
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none_outlined,
                      ),
                      label: Text(_isListening ? 'Listening...' : 'Voice SOS'),
                      onPressed: _isListening || _isStartingVoiceSOS
                          ? null
                          : _startVoiceSOS,
                    ),
                  ),
                  if (_isListening) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Say "SOS", "help", or "emergency".',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 60,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => _confirmAndSendSOS(context),
                      child: const Text('Send SOS Alert'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyStatusCard(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _safetyStatusStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final status = switch (data?['currentSafetyStatus']) {
          'safe' => 'Safe',
          'danger' => 'Danger',
          _ => 'Unknown',
        };
        final colorScheme = Theme.of(context).colorScheme;
        final (
          Color backgroundColor,
          Color foregroundColor,
          IconData icon,
        ) = switch (status) {
          'Danger' => (
            colorScheme.errorContainer,
            colorScheme.onErrorContainer,
            Icons.warning_amber_rounded,
          ),
          'Safe' => (
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
            Icons.check_circle_outline,
          ),
          _ => (
            colorScheme.surfaceContainerHighest,
            colorScheme.onSurfaceVariant,
            Icons.help_outline,
          ),
        };
        final Object? zoneName;
        if (status == 'Danger') {
          zoneName = data?['currentDangerZone'];
        } else if (status == 'Safe') {
          zoneName = data?['currentSafeZone'];
        } else {
          zoneName = null;
        }

        return Card(
          color: backgroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: foregroundColor, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Safety Status: $status',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: foregroundColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (zoneName is String && zoneName.trim().isNotEmpty)
                        Text(
                          zoneName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: foregroundColor),
                        ),
                      if (snapshot.hasError)
                        Text(
                          'Unable to load current safety status.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: foregroundColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSendSOS(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send SOS Alert'),
          content: const Text(
            'Are you sure you want to send an SOS alert with your current location?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        _sendSOS(context);
        return const AlertDialog(
          content: SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }

  Future<void> _sendSOS(BuildContext context) async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        _showSnackBar(context, 'Unable to send SOS. Please sign in again.');
        Navigator.of(context).pop();
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar(
          context,
          'Location services are disabled. Please enable them and try again.',
        );
        Navigator.of(context).pop();
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar(
          context,
          'Location permission denied. Please allow location access and try again.',
        );
        Navigator.of(context).pop();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final fullName = user.displayName ?? '';
      await FirebaseFirestore.instance.collection('sos_alerts').add({
        'userId': user.uid,
        'fullName': fullName,
        'email': user.email ?? '',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        'resolved': false,
      });

      Navigator.of(context).pop();
      _showSnackBar(context, 'SOS alert sent successfully.');
    } catch (error) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showSnackBar(context, 'Unable to send SOS: ${error.toString()}');
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _openMaps(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MapsScreen(locationSyncService: _locationSyncService),
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
    );
  }

  void _openFeedback(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const TouristFeedbackScreen(),
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService authService,
  ) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out'),
          content: const Text('Do you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;
    await _locationSyncService.stopTracking(markOffline: true);
    await authService.logout();
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.width,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    icon,
                    size: 28,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
