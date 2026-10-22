import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_error_messages.dart';
import 'auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _resendVerificationEmail() async {
    await _runWhileLoading(() async {
      await _authService.resendVerificationEmail();
      _setStatus('A new verification email has been sent.');
    });
  }

  Future<void> _checkVerification() async {
    await _runWhileLoading(() async {
      final user = _authService.currentUser;
      if (user == null) {
        _setStatus(
          'You are no longer signed in. Please sign in again.',
          isError: true,
        );
        return;
      }

      await user.reload();
      final refreshedUser = _authService.currentUser;
      if (refreshedUser?.emailVerified == true) {
        _setStatus('Email verified. Opening your account...');
      } else {
        _setStatus(
          'Verification has not been detected yet. Please check your email '
          'and try again.',
          isError: true,
        );
      }
    });
  }

  Future<void> _signOut() async {
    await _runWhileLoading(_authService.logout);
  }

  Future<void> _runWhileLoading(Future<void> Function() operation) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      await operation();
    } on FirebaseAuthException catch (error) {
      _setStatus(friendlyAuthErrorMessage(error), isError: true);
    } on Exception catch (error) {
      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } catch (error) {
      _setStatus(friendlyAuthErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final email = _authService.currentUser?.email ?? 'your email address';
    final emailVerified = FirebaseAuth.instance.currentUser?.emailVerified;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Verify your email',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'A verification email was sent to:',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Firebase emailVerified: $emailVerified',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Verify your email before accessing the app. Check '
                        'your inbox and spam folder for the message.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 20),
                        Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _statusIsError
                                ? colorScheme.error
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isLoading ? null : _checkVerification,
                        child: _isLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Text("I've Verified My Email"),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _resendVerificationEmail,
                        child: const Text('Resend Verification Email'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isLoading ? null : _signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
