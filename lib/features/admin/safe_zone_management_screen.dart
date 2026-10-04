import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SafeZoneManagementScreen extends StatelessWidget {
  const SafeZoneManagementScreen({super.key});

  static final _safeZonesStream = FirebaseFirestore.instance
      .collection('safe_zones')
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Safe Zones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSafeZoneDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Safe Zone'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _safeZonesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load safe zones.',
              detail: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final zones = [...?snapshot.data?.docs]
            ..sort((left, right) {
              final leftName = _zoneName(left.data()).toLowerCase();
              final rightName = _zoneName(right.data()).toLowerCase();
              return leftName.compareTo(rightName);
            });

          if (zones.isEmpty) {
            return const _MessageState(
              icon: Icons.shield_outlined,
              message: 'No safe zones found.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: zones.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _SafeZoneCard(data: zones[index].data()),
          );
        },
      ),
    );
  }
}

Future<void> _showAddSafeZoneDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => const _AddSafeZoneDialog(),
  );
  if (created != true || !context.mounted) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text('Safe zone added successfully.')),
    );
}

class _AddSafeZoneDialog extends StatefulWidget {
  const _AddSafeZoneDialog();

  @override
  State<_AddSafeZoneDialog> createState() => _AddSafeZoneDialogState();
}

class _AddSafeZoneDialogState extends State<_AddSafeZoneDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _radiusController = TextEditingController();
  bool _isSaving = false;
  String? _saveError;

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Safe Zone'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Safe Zone Name',
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a safe zone name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latitudeController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (value) => _validateCoordinate(
                    value,
                    minimum: -90,
                    maximum: 90,
                    label: 'Latitude',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _longitudeController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    prefixIcon: Icon(Icons.explore_outlined),
                  ),
                  validator: (value) => _validateCoordinate(
                    value,
                    minimum: -180,
                    maximum: 180,
                    label: 'Longitude',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _radiusController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Radius in meters',
                    prefixIcon: Icon(Icons.radio_button_checked_outlined),
                  ),
                  validator: _validateRadius,
                ),
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  String? _validateCoordinate(
    String? value, {
    required double minimum,
    required double maximum,
    required String label,
  }) {
    final coordinate = double.tryParse(value?.trim() ?? '');
    if (coordinate == null || !coordinate.isFinite) {
      return 'Enter a valid $label';
    }
    if (coordinate < minimum || coordinate > maximum) {
      return '$label must be between $minimum and $maximum';
    }
    return null;
  }

  String? _validateRadius(String? value) {
    final radius = double.tryParse(value?.trim() ?? '');
    if (radius == null || !radius.isFinite) {
      return 'Enter a valid radius';
    }
    if (radius <= 0) return 'Radius must be greater than zero';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await FirebaseFirestore.instance.collection('safe_zones').add({
        'name': _nameController.text.trim(),
        'latitude': double.parse(_latitudeController.text.trim()),
        'longitude': double.parse(_longitudeController.text.trim()),
        'radius': double.parse(_radiusController.text.trim()),
        'status': 'enabled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = 'Unable to save safe zone.');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to save safe zone: $error')),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

String _zoneName(Map<String, dynamic> data) {
  final name = data['name'];
  return name is String && name.trim().isNotEmpty
      ? name.trim()
      : 'Unnamed zone';
}

String _zoneStatus(Map<String, dynamic> data) {
  final rawStatus = data['status'];
  if (rawStatus is String && rawStatus.trim().isNotEmpty) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'enabled':
      case 'active':
        return 'Enabled';
      case 'disabled':
      case 'inactive':
        return 'Disabled';
    }
  }
  if (rawStatus is bool) return rawStatus ? 'Enabled' : 'Disabled';

  final enabled = data['enabled'] ?? data['isEnabled'];
  return enabled == true ? 'Enabled' : 'Disabled';
}

String _numberValue(Object? value) {
  if (value is! num) return 'Not provided';
  final number = value.toDouble();
  if (number == number.roundToDouble()) return number.toStringAsFixed(0);
  return number.toString();
}

String _radiusValue(Object? value) {
  final radius = _numberValue(value);
  return radius == 'Not provided' ? radius : '$radius m';
}

class _SafeZoneCard extends StatelessWidget {
  const _SafeZoneCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _zoneStatus(data);
    final isEnabled = status == 'Enabled';
    final statusColor = isEnabled
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _zoneName(data),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  avatar: Icon(
                    isEnabled ? Icons.check_circle_outline : Icons.block,
                    size: 18,
                    color: statusColor,
                  ),
                  label: Text(status),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Latitude',
              value: _numberValue(data['latitude']),
            ),
            _DetailRow(
              icon: Icons.explore_outlined,
              label: 'Longitude',
              value: _numberValue(data['longitude']),
            ),
            _DetailRow(
              icon: Icons.radio_button_checked_outlined,
              label: 'Radius',
              value: _radiusValue(data['radius']),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
