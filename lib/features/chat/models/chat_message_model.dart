import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:isar/isar.dart';

part 'chat_message_model.g.dart'; // For Isar generator

@Collection()
class ChatMessage {
  Id isarId = Isar.autoIncrement; // Isar's auto-incrementing ID

  @Index(unique: true, replace: true)
  final String id; // Supabase ID, used for upserting in Isar
  
  @Index() // Index for querying messages by conversation
  final String conversationId;
  
  final String senderId;
  final String senderDisplayName; // For display, fetched by UI if needed
  final String? senderAvatarUrl;   // For display, fetched by UI if needed
  final String? messageText; // Optional caption for images, or text for text messages
  
  @Index() // Index for sorting messages by time
  final DateTime createdAt;
  
  final String messageType; // 'text', 'image', etc.
  final String? imageUrl; // URL for the image if messageType is 'image'
  final String? metadataJson; // Stored as JSON string in Isar

  @Ignore()
  Map<String, dynamic>? get metadata => metadataJson == null ? null : jsonDecode(metadataJson!) as Map<String, dynamic>;

  ChatMessage({
    required this.id, // Supabase ID
    required this.conversationId,
    required this.senderId,
    required this.senderDisplayName,
    this.senderAvatarUrl,
    this.messageText, // Can be null if it's an image without caption
    required this.createdAt,
    required this.messageType,
    this.imageUrl,
    Map<String, dynamic>? metadata, // Accept Map in constructor
    // isarId is not part of the constructor
  }) : metadataJson = metadata == null ? null : jsonEncode(metadata) {
    print('--- ChatMessage Constructor ---');
    print('Received metadata map: $metadata');
    print('Set metadataJson to: $metadataJson');
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Debug print for fromMap
    print('--- ChatMessage.fromMap ---');
    print('Raw map[metadata]: ${map['metadata']} (Type: ${map['metadata']?.runtimeType})');
    // The constructor will be called next, which will print its own logs for the metadata it receives.

    String type = map['message_type'] as String? ?? 'text';
    String? textContent = map['message_text'] as String?;
    String? imgUrl = map['image_url'] as String?;

    if (type == 'text' && textContent == null) {
        textContent = ''; 
    } else if (type == 'image' && imgUrl == null) {
        print("ChatMessage.fromMap: Image message received without image_url. Map: $map");
        type = 'text'; 
        textContent = textContent ?? "[Invalid Image Message]";
    }

    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      senderDisplayName: (map['sender_display_name'] as String?)?.isNotEmpty == true 
                         ? map['sender_display_name'] as String 
                         : map['sender_id'] as String, 
      senderAvatarUrl: map['sender_avatar_url'] as String?,
      messageText: textContent,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      messageType: type,
      imageUrl: imgUrl,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMapForSend() { // For sending new messages
    return {
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message_text': messageText, // Will be caption if image, or text if text_message
      'message_type': messageType,
      'image_url': imageUrl,
      'metadata': this.metadata, // Use the getter to ensure it's a Map for Supabase
      // 'created_at' and 'id' are handled by the database
      // senderDisplayName and senderAvatarUrl are not sent with the message payload
    };
  }
} 