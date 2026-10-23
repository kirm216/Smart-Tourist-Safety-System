import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../tourist/tourist_feedback_model.dart';
import 'admin_service.dart';

class AdminFeedbackManagementScreen extends StatefulWidget {
  const AdminFeedbackManagementScreen({super.key});

  @override
  State<AdminFeedbackManagementScreen> createState() =>
      _AdminFeedbackManagementScreenState();
}

class _AdminFeedbackManagementScreenState
    extends State<AdminFeedbackManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  late final Future<bool> _adminAccess;
  String _search = '';
  String _category = 'All';
  String _status = 'All';
  String _rating = 'All';

  @override
  void initState() {
    super.initState();
    final user = AuthService().currentUser;
    _adminAccess = user == null
        ? Future<bool>.value(false)
        : AdminService().isAdmin(user.uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback Management')),
      body: FutureBuilder<bool>(
        future: _adminAccess,
        builder: (context, accessSnapshot) {
          if (accessSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (accessSnapshot.data != true) {
            return const _FeedbackMessage(
              icon: Icons.lock_outline,
              message: 'Administrator access is required.',
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('feedback').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _FeedbackMessage(
                  icon: Icons.cloud_off_outlined,
                  message: 'Unable to load feedback.',
                  detail: snapshot.error.toString(),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final feedback = [...?snapshot.data?.docs]..sort(_compareNewest);
              final visibleFeedback = feedback.where(_matchesFilters).toList();

              return Column(
                children: [
                  _buildFilters(context),
                  Expanded(
                    child: visibleFeedback.isEmpty
                        ? _FeedbackMessage(
                            icon: Icons.feedback_outlined,
                            message: feedback.isEmpty
                                ? 'No feedback has been submitted.'
                                : 'No feedback matches these filters.',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: visibleFeedback.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final document = visibleFeedback[index];
                              return _FeedbackCard(
                                feedback: TouristFeedback.fromMap(
                                  document.data(),
                                ),
                                onTap: () => _openDetails(document),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search tourist name, email, or comments',
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _filterDropdown(
                  label: 'Category',
                  value: _category,
                  options: ['All', ...TouristFeedback.categories],
                  onChanged: (value) => setState(() => _category = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterDropdown(
                  label: 'Status',
                  value: _status,
                  options: const ['All', 'pending', 'reviewed', 'resolved'],
                  onChanged: (value) => setState(() => _status = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _filterDropdown(
                  label: 'Rating',
                  value: _rating,
                  options: const ['All', '1', '2', '3', '4', '5'],
                  onChanged: (value) => setState(() => _rating = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Newest feedback first',
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (selected) {
        if (selected != null) onChanged(selected);
      },
    );
  }

  bool _matchesFilters(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final item = TouristFeedback.fromMap(document.data());
    if (_category != 'All' && item.category != _category) return false;
    if (_status != 'All' && item.status.toLowerCase() != _status) {
      return false;
    }
    if (_rating != 'All' && item.rating.toString() != _rating) return false;

    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;
    return item.userName.toLowerCase().contains(query) ||
        item.userEmail.toLowerCase().contains(query) ||
        item.comments.toLowerCase().contains(query);
  }

  int _compareNewest(
    QueryDocumentSnapshot<Map<String, dynamic>> left,
    QueryDocumentSnapshot<Map<String, dynamic>> right,
  ) {
    final leftTimestamp = left.data()['timestamp'];
    final rightTimestamp = right.data()['timestamp'];
    final leftDate = leftTimestamp is Timestamp
        ? leftTimestamp.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate = rightTimestamp is Timestamp
        ? rightTimestamp.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  }

  Future<void> _openDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminFeedbackDetailsScreen(document: document),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.feedback, required this.onTap});

  final TouristFeedback feedback;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = feedback.latitude != null && feedback.longitude != null;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
        title: Text(feedback.category),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_touristLabel(feedback)),
              const SizedBox(height: 4),
              Text(
                feedback.comments,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _FeedbackTag(label: _statusLabel(feedback.status)),
                  _FeedbackTag(label: '${feedback.rating}/5 stars'),
                  if (hasLocation)
                    const _FeedbackTag(label: 'Location attached'),
                  _FeedbackTag(label: _formatDate(feedback.timestamp)),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class AdminFeedbackDetailsScreen extends StatefulWidget {
  const AdminFeedbackDetailsScreen({super.key, required this.document});

  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  @override
  State<AdminFeedbackDetailsScreen> createState() =>
      _AdminFeedbackDetailsScreenState();
}

class _AdminFeedbackDetailsScreenState
    extends State<AdminFeedbackDetailsScreen> {
  late final TextEditingController _responseController;
  bool _isSavingResponse = false;
  bool _isUpdatingStatus = false;

  @override
  void initState() {
    super.initState();
    final existingResponse = widget.document.data()['adminResponse'];
    _responseController = TextEditingController(
      text: existingResponse is String ? existingResponse : '',
    );
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: widget.document.reference.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _FeedbackMessage(
              icon: Icons.cloud_off_outlined,
              message: 'Unable to load feedback details.',
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data?.data();
          if (data == null) {
            return const _FeedbackMessage(
              icon: Icons.feedback_outlined,
              message: 'This feedback is no longer available.',
            );
          }
          return _buildDetails(context, TouristFeedback.fromMap(data));
        },
      ),
    );
  }

  Widget _buildDetails(BuildContext context, TouristFeedback item) {
    final theme = Theme.of(context);
    final hasLocation = item.latitude != null && item.longitude != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _DetailsSection(
          title: 'Tourist-submitted information',
          icon: Icons.person_outline,
          children: [
            _DetailLine(label: 'Name', value: _touristName(item)),
            _DetailLine(
              label: 'Email',
              value: item.userEmail.isEmpty ? 'Not provided' : item.userEmail,
            ),
            _DetailLine(label: 'Tourist ID', value: item.userId),
            _DetailLine(label: 'Category', value: item.category),
            _DetailLine(label: 'Rating', value: '${item.rating}/5 stars'),
            _DetailLine(label: 'Submitted', value: _formatDate(item.timestamp)),
            _DetailLine(label: 'Comments', value: item.comments),
            if (hasLocation)
              _DetailLine(
                label: 'Reported location',
                value: '${item.latitude}, ${item.longitude}',
                icon: Icons.location_on_outlined,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailsSection(
          title: 'Administrator review',
          icon: Icons.admin_panel_settings_outlined,
          children: [
            _DetailLine(label: 'Status', value: _statusLabel(item.status)),
            _DetailLine(
              label: 'Last reviewed',
              value: _formatDate(item.reviewedAt),
            ),
            _DetailLine(
              label: 'Reviewer ID',
              value: item.reviewerId ?? 'Not reviewed',
            ),
            if ((item.adminResponse ?? '').trim().isNotEmpty)
              _DetailLine(label: 'Admin response', value: item.adminResponse!),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _responseController,
          enabled: !_isSavingResponse,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Administrator response',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _isSavingResponse ? null : () => _saveResponse(item),
          icon: _isSavingResponse
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save response'),
        ),
        const SizedBox(height: 10),
        if (item.status.toLowerCase() == 'pending')
          OutlinedButton.icon(
            onPressed: _isUpdatingStatus
                ? null
                : () => _updateStatus('reviewed'),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Mark as reviewed'),
          )
        else if (item.status.toLowerCase() == 'reviewed')
          OutlinedButton.icon(
            onPressed: _isUpdatingStatus
                ? null
                : () => _updateStatus('resolved'),
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('Mark as resolved'),
          ),
        if (_isUpdatingStatus)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (hasLocation)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'This safety concern includes a reported location. Review it manually; no danger zone has been created.',
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Future<void> _saveResponse(TouristFeedback item) async {
    if (_isSavingResponse) return;
    final response = _responseController.text.trim();
    if (response.isEmpty) {
      _showMessage('Enter a response before saving.');
      return;
    }
    final user = AuthService().currentUser;
    if (user == null) {
      _showMessage('Administrator sign-in is no longer available.');
      return;
    }

    setState(() => _isSavingResponse = true);
    try {
      await widget.document.reference.update({
        'adminResponse': response,
        'reviewerId': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (item.status.toLowerCase() == 'pending') 'status': 'reviewed',
      });
      if (mounted) _showMessage('Administrator response saved.');
    } catch (error) {
      debugPrint('Unable to save feedback response: $error');
      if (mounted) _showMessage('Unable to save response. Please try again.');
    } finally {
      if (mounted) setState(() => _isSavingResponse = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_isUpdatingStatus) return;
    final user = AuthService().currentUser;
    if (user == null) {
      _showMessage('Administrator sign-in is no longer available.');
      return;
    }
    setState(() => _isUpdatingStatus = true);
    try {
      await widget.document.reference.update({
        'status': status,
        'reviewerId': user.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showMessage(
          status == 'reviewed'
              ? 'Feedback marked as reviewed.'
              : 'Feedback marked as resolved.',
        );
      }
    } catch (error) {
      debugPrint('Unable to update feedback status: $error');
      if (mounted) _showMessage('Unable to update status. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value, this.icon});

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _FeedbackTag extends StatelessWidget {
  const _FeedbackTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    visualDensity: VisualDensity.compact,
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    padding: EdgeInsets.zero,
  );
}

class _FeedbackMessage extends StatelessWidget {
  const _FeedbackMessage({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
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

String _touristName(TouristFeedback feedback) =>
    feedback.userName.trim().isEmpty ? 'Unnamed tourist' : feedback.userName;

String _touristLabel(TouristFeedback feedback) {
  final name = _touristName(feedback);
  return feedback.userEmail.trim().isEmpty
      ? name
      : '$name • ${feedback.userEmail}';
}

String _statusLabel(String status) {
  if (status.isEmpty) return 'Unknown';
  return '${status[0].toUpperCase()}${status.substring(1)}';
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
