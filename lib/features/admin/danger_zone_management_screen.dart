import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DangerZoneManagementScreen extends StatefulWidget {
  const DangerZoneManagementScreen({super.key});

  @override
  State<DangerZoneManagementScreen> createState() =>
      _DangerZoneManagementScreenState();
}

enum _DangerZoneSort { nameAz, nameZa, newest, oldest }

class _DangerZoneManagementScreenState
    extends State<DangerZoneManagementScreen> {
  static const _statusFilters = ['All', 'Enabled', 'Disabled'];
  static final _zonesStream = FirebaseFirestore.instance
      .collection('danger_zones')
      .snapshots();

  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  _DangerZoneSort _sort = _DangerZoneSort.nameAz;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Danger Zones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Danger Zone'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _zonesStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load danger zones.',
              detail: snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allZones = snapshot.data?.docs ?? [];
          final enabledCount = allZones
              .where((zone) => _zoneStatus(zone.data()) == 'Enabled')
              .length;
          final disabledCount = allZones.length - enabledCount;
          final query = _searchQuery.trim().toLowerCase();
          final zones = allZones.where((zone) {
            final data = zone.data();
            final name = _zoneName(data).toLowerCase();
            final level = _dangerLevel(data).toLowerCase();
            final status = _zoneStatus(data);
            final matchesSearch =
                query.isEmpty || name.contains(query) || level.contains(query);
            final matchesStatus =
                _selectedFilter == 'All' || status == _selectedFilter;
            return matchesSearch && matchesStatus;
          }).toList()..sort(_compareZones);

          return Column(
            children: [
              _DangerZoneControls(
                controller: _searchController,
                filters: _statusFilters,
                selectedFilter: _selectedFilter,
                sort: _sort,
                totalCount: allZones.length,
                enabledCount: enabledCount,
                disabledCount: disabledCount,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onFilterChanged: (value) =>
                    setState(() => _selectedFilter = value),
                onSortChanged: (value) => setState(() => _sort = value),
              ),
              Expanded(
                child: zones.isEmpty
                    ? _MessageState(
                        icon: Icons.warning_amber_outlined,
                        message: allZones.isEmpty
                            ? 'No danger zones found.'
                            : 'No danger zones match these filters.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: zones.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final zone = zones[index];
                          return _DangerZoneCard(
                            data: zone.data(),
                            reference: zone.reference,
                            onTap: () => _openForm(context, zone: zone),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _compareZones(
    QueryDocumentSnapshot<Map<String, dynamic>> left,
    QueryDocumentSnapshot<Map<String, dynamic>> right,
  ) {
    final nameComparison = _zoneName(
      left.data(),
    ).toLowerCase().compareTo(_zoneName(right.data()).toLowerCase());
    switch (_sort) {
      case _DangerZoneSort.nameAz:
        return nameComparison;
      case _DangerZoneSort.nameZa:
        return -nameComparison;
      case _DangerZoneSort.newest:
        final timeComparison = _compareDates(
          _createdAt(left.data()),
          _createdAt(right.data()),
          newestFirst: true,
        );
        return timeComparison == 0 ? nameComparison : timeComparison;
      case _DangerZoneSort.oldest:
        final timeComparison = _compareDates(
          _createdAt(left.data()),
          _createdAt(right.data()),
          newestFirst: false,
        );
        return timeComparison == 0 ? nameComparison : timeComparison;
    }
  }

  Future<void> _openForm(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? zone,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _DangerZoneFormDialog(zone: zone),
    );
    if (saved != true || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            zone == null
                ? 'Danger zone added successfully.'
                : 'Danger zone updated successfully.',
          ),
        ),
      );
  }
}

class _DangerZoneControls extends StatelessWidget {
  const _DangerZoneControls({
    required this.controller,
    required this.filters,
    required this.selectedFilter,
    required this.sort,
    required this.totalCount,
    required this.enabledCount,
    required this.disabledCount,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final List<String> filters;
  final String selectedFilter;
  final _DangerZoneSort sort;
  final int totalCount;
  final int enabledCount;
  final int disabledCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_DangerZoneSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search by name or danger level',
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: filters
                .map(
                  (filter) => ChoiceChip(
                    label: Text(filter),
                    selected: selectedFilter == filter,
                    onSelected: (_) => onFilterChanged(filter),
                  ),
                )
                .toList(),
          ),
          Row(
            children: [
              Text('Sort', style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<_DangerZoneSort>(
                  initialValue: sort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: _DangerZoneSort.nameAz,
                      child: Text('Name A–Z'),
                    ),
                    DropdownMenuItem(
                      value: _DangerZoneSort.nameZa,
                      child: Text('Name Z–A'),
                    ),
                    DropdownMenuItem(
                      value: _DangerZoneSort.newest,
                      child: Text('Newest'),
                    ),
                    DropdownMenuItem(
                      value: _DangerZoneSort.oldest,
                      child: Text('Oldest'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total Danger Zones',
                  count: totalCount,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Enabled',
                  count: enabledCount,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Disabled',
                  count: disabledCount,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerZoneFormDialog extends StatefulWidget {
  const _DangerZoneFormDialog({this.zone});

  final QueryDocumentSnapshot<Map<String, dynamic>>? zone;

  @override
  State<_DangerZoneFormDialog> createState() => _DangerZoneFormDialogState();
}

class _DangerZoneFormDialogState extends State<_DangerZoneFormDialog> {
  static const _dangerLevels = ['Low', 'Medium', 'High', 'Critical'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _warningController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _radiusController;
  String? _selectedDangerLevel;
  late String _status;
  bool _isSaving = false;
  String? _saveError;

  bool get _isEditing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    final data = widget.zone?.data() ?? <String, dynamic>{};
    _nameController = TextEditingController(text: _stringValue(data['name']));
    _descriptionController = TextEditingController(
      text: _stringValue(data['description']),
    );
    _warningController = TextEditingController(
      text: _stringValue(data['warningMessage']),
    );
    _latitudeController = TextEditingController(
      text: _numberInput(data['latitude']),
    );
    _longitudeController = TextEditingController(
      text: _numberInput(data['longitude']),
    );
    _radiusController = TextEditingController(
      text: _numberInput(data['radius']),
    );
    final level = _dangerLevel(data);
    _selectedDangerLevel = _dangerLevels.contains(level) ? level : null;
    _status = _zoneStatus(data) == 'Enabled' ? 'enabled' : 'disabled';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _warningController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Danger Zone' : 'Add Danger Zone'),
      content: SizedBox(
        width: 440,
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
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _required('Enter a name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: _required('Enter a description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDangerLevel,
                  decoration: const InputDecoration(
                    labelText: 'Danger Level',
                    prefixIcon: Icon(Icons.warning_amber_outlined),
                  ),
                  items: _dangerLevels
                      .map(
                        (level) =>
                            DropdownMenuItem(value: level, child: Text(level)),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _selectedDangerLevel = value),
                  validator: (value) =>
                      value == null ? 'Select a danger level' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _warningController,
                  enabled: !_isSaving,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Warning Message',
                    prefixIcon: Icon(Icons.campaign_outlined),
                  ),
                  validator: _required('Enter a warning message'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _latitudeController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  validator: (value) => _validateCoordinate(
                    value,
                    min: -90,
                    max: 90,
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
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  validator: (value) => _validateCoordinate(
                    value,
                    min: -180,
                    max: 180,
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
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(
                        value: 'enabled',
                        child: Text('Enabled'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text('Disabled'),
                      ),
                    ],
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _status = value);
                          },
                    validator: (value) =>
                        value == null ? 'Select a status' : null,
                  ),
                ],
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

  FormFieldValidator<String> _required(String message) =>
      (value) => value == null || value.trim().isEmpty ? message : null;

  String? _validateCoordinate(
    String? value, {
    required double min,
    required double max,
    required String label,
  }) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || !number.isFinite) return 'Enter a valid $label';
    if (number < min || number > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }

  String? _validateRadius(String? value) {
    final number = double.tryParse(value?.trim() ?? '');
    if (number == null || !number.isFinite) return 'Enter a valid radius';
    if (number <= 0) return 'Radius must be greater than zero';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final values = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'dangerLevel': _selectedDangerLevel,
      'warningMessage': _warningController.text.trim(),
      'latitude': double.parse(_latitudeController.text.trim()),
      'longitude': double.parse(_longitudeController.text.trim()),
      'radius': double.parse(_radiusController.text.trim()),
    };

    try {
      if (_isEditing) {
        await widget.zone!.reference.update({
          ...values,
          'status': _status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('danger_zones').add({
          ...values,
          'status': 'enabled',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveError = 'Unable to save danger zone.');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to save danger zone: $error')),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DangerZoneCard extends StatefulWidget {
  const _DangerZoneCard({
    required this.data,
    required this.reference,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final DocumentReference<Map<String, dynamic>> reference;
  final VoidCallback onTap;

  @override
  State<_DangerZoneCard> createState() => _DangerZoneCardState();
}

class _DangerZoneCardState extends State<_DangerZoneCard> {
  bool _isDeleting = false;
  bool _isUpdatingStatus = false;

  Future<void> _toggleStatus() async {
    if (_isDeleting || _isUpdatingStatus) return;
    final nextStatus = _zoneStatus(widget.data) == 'Enabled'
        ? 'disabled'
        : 'enabled';
    final nextLabel = nextStatus == 'enabled' ? 'Enabled' : 'Disabled';
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.reference.update({
        'status': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Danger zone set to $nextLabel.')),
        );
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to update danger zone status: $error'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _confirmDelete() async {
    if (_isDeleting || _isUpdatingStatus) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Danger Zone?'),
        content: const Text(
          'Are you sure you want to permanently delete this danger zone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isDeleting = true);
    try {
      await widget.reference.delete();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Danger zone deleted successfully.')),
        );
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Unable to delete danger zone: $error')),
        );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final status = _zoneStatus(data);
    final enabled = status == 'Enabled';
    final statusColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.outline;
    final level = _dangerLevel(data);
    final levelColor = switch (level) {
      'Low' => theme.colorScheme.tertiary,
      'Medium' => theme.colorScheme.secondary,
      'High' => theme.colorScheme.error,
      'Critical' => theme.colorScheme.error,
      _ => theme.colorScheme.outline,
    };
    final busy = _isDeleting || _isUpdatingStatus;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : widget.onTap,
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
                  IconButton(
                    tooltip: 'Delete danger zone',
                    onPressed: busy ? null : _confirmDelete,
                    icon: _isDeleting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    avatar: const Icon(Icons.warning_amber_outlined, size: 18),
                    label: Text(level),
                    side: BorderSide(color: levelColor),
                    labelStyle: TextStyle(color: levelColor),
                  ),
                  ActionChip(
                    avatar: _isUpdatingStatus
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            enabled ? Icons.check_circle_outline : Icons.block,
                            size: 18,
                            color: statusColor,
                          ),
                    label: Text(status),
                    side: BorderSide(color: statusColor),
                    onPressed: busy ? null : _toggleStatus,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: Icons.campaign_outlined,
                label: 'Warning',
                value: _displayValue(data['warningMessage']),
              ),
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

String _zoneName(Map<String, dynamic> data) {
  final name = data['name'];
  return name is String && name.trim().isNotEmpty
      ? name.trim()
      : 'Unnamed zone';
}

String _dangerLevel(Map<String, dynamic> data) {
  final value = data['dangerLevel'];
  if (value is! String || value.trim().isEmpty) return 'Unknown';
  final normalized = value.trim().toLowerCase();
  return switch (normalized) {
    'low' => 'Low',
    'medium' => 'Medium',
    'high' => 'High',
    'critical' => 'Critical',
    _ => value.trim(),
  };
}

String _zoneStatus(Map<String, dynamic> data) {
  final value = data['status'];
  if (value is bool) return value ? 'Enabled' : 'Disabled';
  if (value is String && value.trim().isNotEmpty) {
    return value.trim().toLowerCase() == 'enabled' ? 'Enabled' : 'Disabled';
  }
  return 'Disabled';
}

String _stringValue(Object? value) => value is String ? value.trim() : '';

String _displayValue(Object? value) {
  final text = _stringValue(value);
  return text.isEmpty ? 'Not provided' : text;
}

String _numberInput(Object? value) => value is num ? value.toString() : '';

String _numberValue(Object? value) {
  if (value is! num) return 'Not provided';
  final number = value.toDouble();
  return number == number.roundToDouble()
      ? number.toStringAsFixed(0)
      : number.toString();
}

String _radiusValue(Object? value) {
  final radius = _numberValue(value);
  return radius == 'Not provided' ? radius : '$radius m';
}

DateTime? _createdAt(Map<String, dynamic> data) {
  final value = data['createdAt'];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _compareDates(
  DateTime? left,
  DateTime? right, {
  required bool newestFirst,
}) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return newestFirst ? right.compareTo(left) : left.compareTo(right);
}
