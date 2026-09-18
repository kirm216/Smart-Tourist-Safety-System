import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TouristsScreen extends StatefulWidget {
  const TouristsScreen({super.key});

  @override
  State<TouristsScreen> createState() => _TouristsScreenState();
}

class _TouristsScreenState extends State<TouristsScreen> {
  final _searchController = TextEditingController();
  final _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
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
                      final data = users[index].data();
                      final name = _text(data, 'fullName');
                      final email = _text(data, 'email');
                      final phone = _text(data, 'phone');

                      return Card(
                        elevation: 0,
                        child: ListTile(
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
                                email.isEmpty ? 'Email not provided' : email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                phone.isEmpty ? 'Phone not provided' : phone,
                              ),
                            ],
                          ),
                          isThreeLine: true,
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
