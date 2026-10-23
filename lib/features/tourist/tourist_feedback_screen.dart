import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../auth/auth_service.dart';
import 'tourist_feedback_model.dart';

class TouristFeedbackScreen extends StatefulWidget {
  const TouristFeedbackScreen({super.key});

  @override
  State<TouristFeedbackScreen> createState() => _TouristFeedbackScreenState();
}

class _TouristFeedbackScreenState extends State<TouristFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentsController = TextEditingController();
  String? _category;
  int? _rating;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    final user = AuthService().currentUser;
    if (user == null) {
      _showMessage('Please sign in to submit feedback.');
      return;
    }

    setState(() => _isSubmitting = true);
    var locationUnavailable = false;
    try {
      double? latitude;
      double? longitude;
      if (_category == 'Safety concern / Dangerous place') {
        final position = await _tryGetCurrentPosition();
        if (position == null) {
          locationUnavailable = true;
        } else {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      }

      await FirebaseFirestore.instance
          .collection('feedback')
          .add(
            TouristFeedback(
              category: _category!,
              rating: _rating!,
              comments: _commentsController.text.trim(),
              timestamp: null,
              status: 'pending',
              adminResponse: null,
            ).toSubmission(
              userId: user.uid,
              userName: user.displayName?.trim() ?? '',
              userEmail: user.email ?? '',
              latitude: latitude,
              longitude: longitude,
            ),
          );

      if (!mounted) return;
      _formKey.currentState!.reset();
      setState(() {
        _category = null;
        _rating = null;
        _commentsController.clear();
      });
      _showMessage(
        locationUnavailable
            ? 'Feedback submitted. Current location was unavailable, so it was not attached.'
            : 'Feedback submitted successfully.',
      );
    } catch (error) {
      debugPrint('Unable to submit tourist feedback: $error');
      if (mounted) _showMessage('Unable to submit feedback. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<Position?> _tryGetCurrentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (error) {
      debugPrint('Unable to attach location to feedback: $error');
      return null;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feedback'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Send feedback'),
              Tab(text: 'My feedback'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildSubmissionForm(context), _buildFeedbackHistory()],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Share your feedback',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
            items: TouristFeedback.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) =>
                value == null || value.isEmpty ? 'Select a category' : null,
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _category = value),
          ),
          if (_category == 'Safety concern / Dangerous place') ...[
            const SizedBox(height: 8),
            Text(
              'Your current location may be attached if location access is available.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          Text('Rating', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          FormField<int>(
            initialValue: _rating,
            validator: (value) => value == null || value < 1 || value > 5
                ? 'Choose a rating from 1 to 5 stars'
                : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      tooltip: '${index + 1} stars',
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() => _rating = index + 1);
                              field.didChange(index + 1);
                            },
                      icon: Icon(
                        index < (_rating ?? 0) ? Icons.star : Icons.star_border,
                        color: Theme.of(context).colorScheme.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                if (field.errorText != null)
                  Text(
                    field.errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _commentsController,
            enabled: !_isSubmitting,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Comments',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Enter your comments' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submitFeedback,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit feedback'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackHistory() {
    final user = AuthService().currentUser;
    if (user == null) {
      return const Center(child: Text('Sign in to view your feedback.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('feedback')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to load feedback history. Please try again.'),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data?.docs.toList() ?? [];
        documents.sort((left, right) {
          final leftTime = left.data()['timestamp'];
          final rightTime = right.data()['timestamp'];
          final leftDate = leftTime is Timestamp
              ? leftTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate = rightTime is Timestamp
              ? rightTime.toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        });

        if (documents.isEmpty) {
          return const Center(child: Text('You have not submitted feedback.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: documents.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = TouristFeedback.fromMap(documents[index].data());
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text('${item.rating}/5'),
                        const Spacer(),
                        Text(_formatDate(item.timestamp)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(item.comments),
                    const SizedBox(height: 10),
                    Chip(label: Text(_formatStatus(item.status))),
                    if (item.adminResponse?.trim().isNotEmpty == true) ...[
                      const Divider(),
                      Text(
                        'Admin response',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(item.adminResponse!),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return '${status[0].toUpperCase()}${status.substring(1)}';
  }
}
