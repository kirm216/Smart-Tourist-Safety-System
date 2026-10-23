import 'package:cloud_firestore/cloud_firestore.dart';

class TouristFeedback {
  const TouristFeedback({
    required this.category,
    required this.rating,
    required this.comments,
    required this.timestamp,
    required this.status,
    required this.adminResponse,
    this.userId = '',
    this.userName = '',
    this.userEmail = '',
    this.latitude,
    this.longitude,
    this.reviewerId,
    this.reviewedAt,
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
  final String userId;
  final String userName;
  final String userEmail;
  final double? latitude;
  final double? longitude;
  final String? reviewerId;
  final DateTime? reviewedAt;

  factory TouristFeedback.fromMap(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    final adminResponse = data['adminResponse'];
    final reviewedAt = data['reviewedAt'];
    return TouristFeedback(
      category: data['category'] is String ? data['category'] as String : '',
      rating: data['rating'] is int ? data['rating'] as int : 0,
      comments: data['comments'] is String ? data['comments'] as String : '',
      timestamp: timestamp is Timestamp ? timestamp.toDate() : null,
      status: data['status'] is String ? data['status'] as String : 'unknown',
      adminResponse: adminResponse is String ? adminResponse : null,
      userId: data['userId'] is String ? data['userId'] as String : '',
      userName: data['userName'] is String ? data['userName'] as String : '',
      userEmail: data['userEmail'] is String ? data['userEmail'] as String : '',
      latitude: data['latitude'] is num
          ? (data['latitude'] as num).toDouble()
          : null,
      longitude: data['longitude'] is num
          ? (data['longitude'] as num).toDouble()
          : null,
      reviewerId: data['reviewerId'] is String
          ? data['reviewerId'] as String
          : null,
      reviewedAt: reviewedAt is Timestamp ? reviewedAt.toDate() : null,
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
