import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _contactsStream(String uid) {
    return _firestore
        .collection('emergency_contacts')
        .doc(uid)
        .collection('contacts')
        .orderBy('name')
        .snapshots();
  }

  Future<void> _showContactDialog({
    DocumentSnapshot<Map<String, dynamic>>? contact,
  }) async {
    final nameController = TextEditingController(
      text: contact?.data()?['name'] as String? ?? '',
    );
    final phoneController = TextEditingController(
      text: contact?.data()?['phone'] as String? ?? '',
    );
    final relationshipController = TextEditingController(
      text: contact?.data()?['relationship'] as String? ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final user = AuthService().currentUser;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(contact == null ? 'Add contact' : 'Edit contact'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: relationshipController,
                  decoration: const InputDecoration(labelText: 'Relationship'),
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a relationship';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final contactData = {
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'relationship': relationshipController.text.trim(),
                };

                try {
                  final contactsRef = _firestore
                      .collection('emergency_contacts')
                      .doc(user.uid)
                      .collection('contacts');

                  if (contact == null) {
                    await contactsRef.add(contactData);
                  } else {
                    await contactsRef
                        .doc(contact.id)
                        .set(contactData, SetOptions(merge: true));
                  }

                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          contact == null
                              ? 'Contact added successfully.'
                              : 'Contact updated successfully.',
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
                        content: Text(
                          'Unable to save contact: ${error.toString()}',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                }
              },
              child: Text(contact == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContact(String uid, String contactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete contact'),
          content: const Text('Are you sure you want to delete this contact?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _firestore
          .collection('emergency_contacts')
          .doc(uid)
          .collection('contacts')
          .doc(contactId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Contact deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Unable to delete contact: ${error.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showContactDialog(),
              tooltip: 'Add contact',
            ),
        ],
      ),
      body: SafeArea(
        child: user == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Please sign in to manage emergency contacts.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _contactsStream(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Unable to load contacts. Please try again later.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    );
                  }

                  final contacts = snapshot.data?.docs ?? [];
                  if (contacts.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No emergency contacts yet.',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Add trusted contacts to quickly access them in an emergency.',
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => _showContactDialog(),
                              child: const Text('Add contact'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: contacts.length,
                    itemBuilder: (context, index) {
                      final document = contacts[index];
                      final data = document.data();
                      final name = data['name'] as String? ?? 'Unknown';
                      final phone = data['phone'] as String? ?? '';
                      final relationship =
                          data['relationship'] as String? ?? '';

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          title: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text('$relationship · $phone'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showContactDialog(contact: document);
                              } else if (value == 'delete') {
                                _deleteContact(user.uid, document.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                  );
                },
              ),
      ),
      floatingActionButton: user != null
          ? FloatingActionButton(
              onPressed: () => _showContactDialog(),
              child: const Icon(Icons.add),
              tooltip: 'Add contact',
            )
          : null,
    );
  }
}
