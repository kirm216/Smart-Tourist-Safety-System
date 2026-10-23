import 'package:cloud_firestore/cloud_firestore.dart';

class TouristFeedback {
  const TouristFeedback({
    required this.category,
    required this.rating,
    required this.comments,
    required this.timestamp,
    required this.status,
    required this.adminResponse,
  });

  static const categories = [
    'Application experience',
    'Safety services',
    'Emergency response',
    'Map and location services',
    'Safety concern / Dangerous place',
    'Suggestions',
    'Other',
  ];

  final String category;
  final int rating;
  final String comments;
  final DateTime? timestamp;
  final String status;
  final String? adminResponse;

  factory TouristFeedback.fromMap(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    final adminResponse = data['adminResponse'];
    return TouristFeedback(
      category: data['category'] is String ? data['category'] as String : '',
      rating: data['rating'] is int ? data['rating'] as int : 0,
      comments: data['comments'] is String ? data['comments'] as String : '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
      status: data['status'] is String ? data['status'] as String : 'unknown',
      adminResponse: adminResponse is String ? adminResponse : null,
    );
  }

  Map<String, Object?> toSubmission({
    required String userId,
    required String userName,
    required String userEmail,
    required double? latitude,
    required double? longitude,
  }) => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'category': category,
    'rating': rating,
    'comments': comments,
    'timestamp': FieldValue.serverTimestamp(),
    'status': 'pending',
    if (latitude != null && longitude != null) ...{
      'latitude': latitude,
      'longitude': longitude,
    },
  };
}
