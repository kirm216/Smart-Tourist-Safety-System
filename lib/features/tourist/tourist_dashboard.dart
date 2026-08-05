import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../profile/profile_screen.dart';

class TouristDashboard extends StatelessWidget {
  const TouristDashboard({super.key});

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
                          const SizedBox(height: 20),
                          Wrap(
                            runSpacing: 16,
                            spacing: 16,
                            children: [
                              FilledButton.tonalIcon(
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                label: const Text('Overview'),
                                onPressed: () {},
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.location_on_outlined),
                                label: const Text('Travel safety'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
                            onTap: () => _navigateToSection(context, 'SOS'),
                            width: cardWidth,
                          ),
                          _ActionCard(
                            title: 'Maps',
                            subtitle: 'Find nearby routes',
                            icon: Icons.map_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            onTap: () => _navigateToSection(context, 'Maps'),
                            width: cardWidth,
                          ),
                          _ActionCard(
                            title: 'Safe Zones',
                            subtitle: 'Secure locations',
                            icon: Icons.shield_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            onTap: () =>
                                _navigateToSection(context, 'Safe Zones'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToSection(BuildContext context, String section) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Navigation placeholder: $section screen coming soon.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => const ProfileScreen()),
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
