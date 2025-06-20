// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:leancloud_storage/leancloud.dart';

// Remove part directive since we're not using code generation
// part 'reply_model.g.dart';

class Reply {
  final String id;
  final String offerId;
  final String offerOwnerId;
  final String userId;
  final String userDisplayName;
  final String userAvatarUrl;
  final double rate;
  final double? amount;
  final String message;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic;
  final String status;
  final String? transactionSummaryForReplier;

  Reply({
    required this.id,
    required this.offerId,
    required this.offerOwnerId,
    required this.userId,
    required this.userDisplayName,
    required this.userAvatarUrl,
    required this.rate,
    this.amount,
    required this.message,
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
    this.status = 'pending',
    this.transactionSummaryForReplier,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'offerId': offerId,
      'offerOwnerId': offerOwnerId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userAvatarUrl': userAvatarUrl,
      'rate': rate,
      'amount': amount,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isPublic': isPublic,
      'status': status,
      'transaction_summary_for_replier': transactionSummaryForReplier,
    };
  }

  factory Reply.fromMap(Map<String, dynamic> data) {
    DateTime? parsedCreatedAt;
    if (data['created_at'] is String) {
      parsedCreatedAt = DateTime.parse(data['created_at']).toLocal();
    } else if (data['created_at'] is DateTime) {
      parsedCreatedAt = data['created_at'].toLocal();
    }
    parsedCreatedAt ??= DateTime.now();

    DateTime? parsedUpdatedAt;
    if (data['updated_at'] is String) {
      parsedUpdatedAt = DateTime.parse(data['updated_at']).toLocal();
    } else if (data['updated_at'] is DateTime) {
      parsedUpdatedAt = data['updated_at'].toLocal();
    }

    return Reply(
      id: data['id']?.toString() ?? '',
      offerId: data['offer_id']?.toString() ?? '',
      offerOwnerId: data['offer_owner_id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      userDisplayName: data['user_display_name']?.toString() ?? '',
      userAvatarUrl: data['user_avatar_url']?.toString() ?? '',
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (data['amount'] as num?)?.toDouble(),
      message: data['message']?.toString() ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      isPublic: data['is_public'] ?? true,
      status: data['status']?.toString() ?? 'pending',
      transactionSummaryForReplier: data['transaction_summary_for_replier'] as String?,
    );
  }

  Reply copyWith({
    String? id,
    String? offerId,
    String? offerOwnerId,
    String? userId,
    String? userDisplayName,
    String? userAvatarUrl,
    double? rate,
    double? amount,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? status,
    String? transactionSummaryForReplier,
  }) {
    return Reply(
      id: id ?? this.id,
      offerId: offerId ?? this.offerId,
      offerOwnerId: offerOwnerId ?? this.offerOwnerId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      rate: rate ?? this.rate,
      amount: amount ?? this.amount,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      status: status ?? this.status,
      transactionSummaryForReplier: transactionSummaryForReplier ?? this.transactionSummaryForReplier,
    );
  }
}