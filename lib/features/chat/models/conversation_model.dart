import 'package:isar/isar.dart';

part 'conversation_model.g.dart'; // For Isar generator

@Collection()
class Conversation {
  // Isar local auto-incrementing ID
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true) // Index for querying by Supabase ID, replace on conflict
  final String id; // Supabase ID

  final String user1Id;
  final String user2Id;
  final String contextOfferId; // Updated from offerId
  final String contextReplyId; // Updated from replyId
  final String user1DisplayName; // To display in chat list
  final String user2DisplayName; // To display in chat list
  final String? user1AvatarUrl;
  final String? user2AvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId; // To know if the last message was from the current user
  final int unreadCount; // For current user

  Conversation({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.contextOfferId, // Updated
    required this.contextReplyId, // Updated
    required this.user1DisplayName,
    required this.user2DisplayName,
    this.user1AvatarUrl,
    this.user2AvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = 0,
  });

  // Returns the display name of the other user in the conversation
  String getOtherUserDisplayName(String currentUserId) {
    return currentUserId == user1Id ? user2DisplayName : user1DisplayName;
  }

  String getOtherUserAvatarUrl(String currentUserId) {
    return currentUserId == user1Id ? (user2AvatarUrl ?? '') : (user1AvatarUrl ?? '');
  }

  String getOtherUserId(String currentUserId) {
    return currentUserId == user1Id ? user2Id : user1Id;
  }

  factory Conversation.fromMap(Map<String, dynamic> map, String currentUserId) {
    return Conversation(
      id: map['id'] as String,
      user1Id: map['user1_id'] as String,
      user2Id: map['user2_id'] as String,
      contextOfferId: map['context_offer_id'] as String? ?? '', // Updated
      contextReplyId: map['context_reply_id'] as String? ?? '', // Updated
      user1DisplayName: map['user1_display_name'] as String? ?? map['user1_id'] as String,
      user2DisplayName: map['user2_display_name'] as String? ?? map['user2_id'] as String,
      user1AvatarUrl: map['user1_avatar_url'] as String?,
      user2AvatarUrl: map['user2_avatar_url'] as String?,
      lastMessage: map['last_message_text'] as String?,
      lastMessageAt: map['last_message_at'] != null 
          ? DateTime.parse(map['last_message_at'] as String).toLocal() 
          : null,
      lastMessageSenderId: map['last_message_sender_id'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMapForInsert() {
    return {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'context_offer_id': contextOfferId, // Updated
      'context_reply_id': contextReplyId, // Updated
    };
  }

  // A simplified toMap if needed, though typically we fetch, not push entire conversations like this
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1_id': user1Id,
      'user2_id': user2Id,
      // We might not store display names directly in the conversations table if they can change
      // 'user1_display_name': user1DisplayName, 
      // 'user2_display_name': user2DisplayName,
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'last_message_sender_id': lastMessageSenderId,
    };
  }
} 