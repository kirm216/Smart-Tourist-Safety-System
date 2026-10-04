import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import 'danger_zone_management_screen.dart';
import 'geofence_events_screen.dart';
import 'safe_zone_management_screen.dart';
import 'sos_management_screen.dart';
import 'tourists_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Log out',
            onPressed: () => AuthService().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _DashboardCard(
                    icon: Icons.people_alt_outlined,
                    label: 'Registered Tourists',
                    color: colorScheme.primary,
                  ),
                  _DashboardCard(
                    icon: Icons.crisis_alert_outlined,
                    label: 'Active SOS Alerts',
                    color: colorScheme.error,
                  ),
                  _DashboardCard(
                    icon: Icons.location_on_outlined,
                    label: 'Geo-fence Events',
                    color: colorScheme.tertiary,
                  ),
                  _DashboardCard(
                    icon: Icons.shield_outlined,
                    label: 'Safe Zones',
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ActionButton(
                icon: Icons.people_alt_outlined,
                label: 'Manage Tourists',
                onPressed: () => _open(context, const TouristsScreen()),
              ),
              _ActionButton(
                icon: Icons.crisis_alert_outlined,
                label: 'Manage SOS Alerts',
                onPressed: () => _open(context, const SosManagementScreen()),
              ),
              _ActionButton(
                icon: Icons.location_on_outlined,
                label: 'Geo-fence Events',
                onPressed: () => _open(context, const GeofenceEventsScreen()),
              ),
              _ActionButton(
                icon: Icons.shield_outlined,
                label: 'Manage Safe Zones',
                onPressed: () =>
                    _open(context, const SafeZoneManagementScreen()),
              ),
              _ActionButton(
                icon: Icons.warning_amber_outlined,
                label: 'Manage Danger Zones',
                onPressed: () =>
                    _open(context, const DangerZoneManagementScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Loading...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(label, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
