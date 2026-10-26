import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'features/admin/admin_dashboard.dart';
import 'features/admin/admin_service.dart';
import 'features/auth/email_verification_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/tourist/tourist_dashboard.dart';

class TouristSafetyApp extends StatelessWidget {
  const TouristSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Tourist Safety System',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Unable to verify sign-in state. Please restart the app.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<bool>(
          future: AdminService().isAdmin(user.uid),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (adminSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Unable to verify administrator access. Please try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (adminSnapshot.data == true) {
              return const AdminDashboard();
            }

            if (!user.emailVerified) {
              return const EmailVerificationScreen();
            }

            return _TouristApprovalGate(user: user);
          },
        );
      },
    );
  }
}

class _TouristApprovalGate extends StatefulWidget {
  const _TouristApprovalGate({required this.user});

  final User user;

  @override
  State<_TouristApprovalGate> createState() => _TouristApprovalGateState();
}

class _TouristApprovalGateState extends State<_TouristApprovalGate> {
  late Future<String?> _approvalStatus;

  @override
  void initState() {
    super.initState();
    _approvalStatus = _readApprovalStatus();
  }

  Future<String?> _readApprovalStatus() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    final status = snapshot.data()?['approvalStatus'];
    if (status is! String) return null;
    final normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus.isEmpty ? null : normalizedStatus;
  }

  void _retry() {
    setState(() => _approvalStatus = _readApprovalStatus());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _approvalStatus,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ApprovalStatusScreen(
            title: 'Approval Status Unavailable',
            message:
                'We could not load your approval status. Please try again or '
                'contact the administrator.',
            onRetry: _retry,
          );
        }

        switch (snapshot.data) {
          case 'approved':
            return const TouristDashboard();
          case 'pending':
            return const _ApprovalStatusScreen(
              title: 'Waiting for Admin Approval',
              message:
                  'Your registration is pending admin approval. Please wait '
                  'for the administrator to review your registration.',
            );
          case 'rejected':
            return const _ApprovalStatusScreen(
              title: 'Registration Rejected',
              message:
                  'Your registration was not approved. Please contact the '
                  'administrator if you believe this is a mistake.',
            );
          default:
            return const _ApprovalStatusScreen(
              title: 'Approval Status Unavailable',
              message:
                  'Your approval status is missing or invalid. Please contact '
                  'the administrator.',
            );
        }
      },
    );
  }
}

class _ApprovalStatusScreen extends StatefulWidget {
  const _ApprovalStatusScreen({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  State<_ApprovalStatusScreen> createState() => _ApprovalStatusScreenState();
}

class _ApprovalStatusScreenState extends State<_ApprovalStatusScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await AuthService().logout();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Unable to sign out: $error')));
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(widget.message, textAlign: TextAlign.center),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: widget.onRetry,
                    child: const Text('Retry'),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isSigningOut ? null : _signOut,
                  child: _isSigningOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
