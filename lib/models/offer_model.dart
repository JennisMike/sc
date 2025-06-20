import 'package:flutter/foundation.dart'; // Added for ValueGetter
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:hive/hive.dart';
import 'reply_model.dart';

// Remove part directive since we're not using code generation
// part 'offer_model.g.dart';

class Offer {
  final String id;
  final String userId;
  final String userDisplayName;
  final String userAvatarUrl;
  final String type; // 'Need RMB', 'Need FCFA', 'RMB available'
  final double amount;
  final double? rate;
  final String message;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // 'active', 'accepted', 'completed', 'cancelled'
  final String? acceptedByUserId;
  final DateTime? acceptedAt;
  final List<Reply> replies;

  Offer({
    required this.id,
    required this.userId,
    required this.userDisplayName,
    required this.userAvatarUrl,
    required this.type,
    required this.amount,
    this.rate,
    required this.message,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.acceptedByUserId,
    this.acceptedAt,
    this.replies = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'user_display_name': userDisplayName,
      'user_avatar_url': userAvatarUrl,
      'type': type,
      'amount': amount,
      'rate': rate,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'status': status,
      'accepted_by_user_id': acceptedByUserId,
      'accepted_at': acceptedAt?.toIso8601String(),
      'replies': replies.map((e) => e.toMap()).toList(),
    };
  }

  factory Offer.fromMap(Map<String, dynamic> data) {
    DateTime? parsedCreatedAt;
    if (data['created_at'] is String) {
      try {
        parsedCreatedAt = DateTime.parse(data['created_at']).toLocal();
      } catch (e) {
        print('Error parsing created_at: $e');
        parsedCreatedAt = DateTime.now();
      }
    } else if (data['created_at'] is DateTime) {
      parsedCreatedAt = data['created_at'].toLocal();
    }
    parsedCreatedAt ??= DateTime.now();

    DateTime? parsedUpdatedAt;
    if (data['updated_at'] is String) {
      try {
        parsedUpdatedAt = DateTime.parse(data['updated_at']).toLocal();
      } catch (e) {
        print('Error parsing updated_at: $e');
        parsedUpdatedAt = DateTime.now();
      }
    } else if (data['updated_at'] is DateTime) {
      parsedUpdatedAt = data['updated_at'].toLocal();
    }
    parsedUpdatedAt ??= DateTime.now();

    DateTime? parsedAcceptedAt;
    if (data['accepted_at'] is String) {
      try {
        parsedAcceptedAt = DateTime.parse(data['accepted_at']).toLocal();
      } catch (e) {
        print('Error parsing accepted_at: $e');
        parsedAcceptedAt = null;
      }
    } else if (data['accepted_at'] is DateTime) {
      parsedAcceptedAt = data['accepted_at'].toLocal();
    }

    final id = data['id']?.toString() ?? '';
    final userId = data['user_id']?.toString() ?? '';
    final userDisplayName = data['user_display_name']?.toString() ?? '';
    final userAvatarUrl = data['user_avatar_url']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final rate = (data['rate'] as num?)?.toDouble();
    final message = data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'active';
    final acceptedByUserId = data['accepted_by_user_id']?.toString();

    return Offer(
      id: id,
      userId: userId,
      userDisplayName: userDisplayName,
      userAvatarUrl: userAvatarUrl,
      type: type,
      amount: amount,
      rate: rate,
      message: message,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      status: status,
      acceptedByUserId: acceptedByUserId,
      acceptedAt: parsedAcceptedAt,
      replies: (data['replies'] as List<dynamic>?)
          ?.map((e) => Reply.fromMap(Map<String, dynamic>.from(e)))
          .toList() ?? [],
    );
  }

  Offer copyWith({
    String? id,
    String? userId,
    String? userDisplayName,
    String? userAvatarUrl,
    String? type,
    double? amount,
    double? rate,
    String? message,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
    String? acceptedByUserId,
    DateTime? acceptedAt,
    List<Reply>? replies,
  }) {
    return Offer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      rate: rate ?? this.rate,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      acceptedByUserId: acceptedByUserId ?? this.acceptedByUserId,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      replies: replies ?? this.replies,
    );
  }
}

// Manual Hive Adapter for Offer
// class OfferAdapter extends TypeAdapter<Offer> {
//   @override
//   final int typeId = 0;
//
//   @override
//   Offer read(BinaryReader reader) {
//     final map = reader.readMap().cast<String, dynamic>();
//     return Offer.fromMap(map);
//   }
//
//   @override
//   void write(BinaryWriter writer, Offer obj) {
//     writer.writeMap(obj.toMap());
//   }
// }