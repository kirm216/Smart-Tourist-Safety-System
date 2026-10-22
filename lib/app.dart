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

            return user.emailVerified
                ? const TouristDashboard()
                : const EmailVerificationScreen();
          },
        );
      },
    );
  }
}
