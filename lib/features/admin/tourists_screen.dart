import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TouristsScreen extends StatefulWidget {
  const TouristsScreen({super.key});

  @override
  State<TouristsScreen> createState() => _TouristsScreenState();
}

class _TouristsScreenState extends State<TouristsScreen> {
  final _searchController = TextEditingController();
  final _usersStream = FirebaseFirestore.instance
      .collection('users')
      .snapshots();
  final _approvalUpdates = <String, String>{};
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _text(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value.trim() : '';
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filteredUsers(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_searchQuery.isEmpty) return snapshot.docs;

    return snapshot.docs.where((document) {
      final data = document.data();
      return _text(data, 'fullName').toLowerCase().contains(_searchQuery) ||
          _text(data, 'email').toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registered Tourists')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SearchBar(
                controller: _searchController,
                leading: const Icon(Icons.search),
                hintText: 'Search by name or email',
                trailing: [
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                    ),
                ],
                onChanged: (value) {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _usersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MessageState(
                      icon: Icons.cloud_off_outlined,
                      message: 'Unable to load registered tourists.',
                      detail: snapshot.error.toString(),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = _filteredUsers(snapshot.data!);
                  if (users.isEmpty) {
                    return _MessageState(
                      icon: Icons.people_outline,
                      message: _searchQuery.isEmpty
                          ? 'No registered tourists found.'
                          : 'No tourists match your search.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final data = user.data();
                      final name = _text(data, 'fullName');
                      final email = _text(data, 'email');
                      final phone = _text(data, 'phone');
                      final digitalTouristId = _text(data, 'digitalTouristId');
                      final approvalStatus = _text(data, 'approvalStatus');
                      final isPending =
                          approvalStatus.toLowerCase() == 'pending';
                      final updateInProgress = _approvalUpdates.containsKey(
                        user.id,
                      );
                      final currentAction = _approvalUpdates[user.id];
                      final statusLabel = approvalStatus.isEmpty
                          ? 'Not provided'
                          : '${approvalStatus[0].toUpperCase()}${approvalStatus.substring(1).toLowerCase()}';

                      return Card(
                        elevation: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                child: Text(
                                  name.isEmpty ? '?' : name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? 'Unnamed tourist' : name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email.isEmpty
                                        ? 'Email not provided'
                                        : email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Digital Tourist ID: ${digitalTouristId.isEmpty ? 'Not available' : digitalTouristId}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    phone.isEmpty
                                        ? 'Phone not provided'
                                        : phone,
                                  ),
                                ],
                              ),
                              trailing: Chip(
                                label: Text(statusLabel),
                                visualDensity: VisualDensity.compact,
                              ),
                              isThreeLine: true,
                            ),
                            if (isPending)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  72,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: updateInProgress
                                            ? null
                                            : () => _updateApprovalStatus(
                                                user,
                                                'rejected',
                                              ),
                                        icon: currentAction == 'rejected'
                                            ? const SizedBox.square(
                                                dimension: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.close),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: updateInProgress
                                            ? null
                                            : () => _updateApprovalStatus(
                                                user,
                                                'approved',
                                              ),
                                        icon: currentAction == 'approved'
                                            ? const SizedBox.square(
                                                dimension: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.check),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateApprovalStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> user,
    String status,
  ) async {
    if (_approvalUpdates.containsKey(user.id)) return;
    setState(() => _approvalUpdates[user.id] = status);

    try {
      await user.reference.update({'approvalStatus': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Tourist approved successfully.'
                  : 'Tourist rejected successfully.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to update approval status: $error'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _approvalUpdates.remove(user.id));
      }
    }
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
