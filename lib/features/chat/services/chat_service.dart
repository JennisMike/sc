import 'dart:io'; // For File type
import 'dart:async'; // For StreamController and Stream
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p; // For getting file extension
import '../models/conversation_model.dart'; // Import Conversation model
import '../models/chat_message_model.dart'; // Import ChatMessage (though not directly used in getConversationsStream)
import './isar_chat_cache_service.dart'; // Import IsarChatCacheService
import 'package:rxdart/rxdart.dart';
import '../../../models/user_model.dart'; // For UserProfileService access to UserModel
import './user_profile_service.dart'; // Import UserProfileService

class ChatService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final IsarChatCacheService _cacheService;
  final UserProfileService _userProfileService = UserProfileService(); // Instantiate UserProfileService
  static const String chatImageBucket = 'chat-images'; // Corrected bucket name

  ChatService(this._cacheService);

  // Modify constructor to accept IsarChatCacheService
  // ChatService();

  // Future<String> createConversation(String userId1, String userId2) async {
  //   // Logic to create a new conversation, ensuring no duplicates
  //   // Returns the conversation ID
  //   return ''; 
  // }

  // Stream<List<ChatMessage>> getMessages(String conversationId) {
  //   // Stream messages for a given conversation
  //   return Stream.value([]);
  // }

  // Future<void> sendMessage({
  //   required String conversationId,
  //   required String senderId,
  //   required String text,
  // }) async {
  //   // Send a message
  // }

  // Stream<List<Conversation>> getConversations(String userId) {
  //   // Stream user's conversations
  //   return Stream.value([]); 
  // }

  // Placeholder for initializing real-time subscriptions if needed
  // Future<void> init() async {}
  
  // Placeholder for disposing resources
  // void dispose() {}

  // Example: Creating a conversation
  Future<String?> createOrGetConversation(String currentUserId, String otherUserId) async {
    // Ensure user IDs are ordered to create a consistent composite key
    final users = [currentUserId, otherUserId]..sort();
    final user1 = users[0];
    final user2 = users[1];

    // Check if a conversation already exists
    final existingConversation = await _supabaseClient
        .from('conversations')
        .select('id')
        // Updated OR condition for robustness, assuming user1_id is always less than user2_id in DB
        .eq('user1_id', user1)
        .eq('user2_id', user2)
        .limit(1)
        .maybeSingle();

    if (existingConversation != null && existingConversation['id'] != null) {
      return existingConversation['id'] as String;
    }

    // If not, create a new one
    // Fetch profile data to store display names initially
    String? user1InitialName = user1;
    String? user1InitialAvatar;
    String? user2InitialName = user2;
    String? user2InitialAvatar;
    try {
      final profile1Data = await _supabaseClient.from('profiles').select('username, profile_picture').eq('id', user1).maybeSingle();
      if (profile1Data != null) {
        user1InitialName = profile1Data['username'] as String? ?? user1;
        user1InitialAvatar = profile1Data['profile_picture'] as String?;
      }
      final profile2Data = await _supabaseClient.from('profiles').select('username, profile_picture').eq('id', user2).maybeSingle();
      if (profile2Data != null) {
        user2InitialName = profile2Data['username'] as String? ?? user2;
        user2InitialAvatar = profile2Data['profile_picture'] as String?;
      }
    } catch (e) {
      print("ChatService: Error fetching initial profiles for general conversation creation: $e");
    }

    final newConversation = await _supabaseClient.from('conversations').insert({
      'user1_id': user1,
      'user2_id': user2,
      'user1_display_name': user1InitialName,
      'user1_avatar_url': user1InitialAvatar,
      'user2_display_name': user2InitialName,
      'user2_avatar_url': user2InitialAvatar,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    return newConversation['id'] as String?;
  }

  Future<String?> createConversationForOffer({
    required String offerOwnerId,
    required String replyUserId,
    required String offerId,
    required String replyId,
  }) async {
    final List<String> userIds = [offerOwnerId, replyUserId]..sort();
    final String user1 = userIds[0];
    final String user2 = userIds[1];

    final existingConversationResponse = await _supabaseClient
        .from('conversations')
        .select('id, context_offer_id, context_reply_id')
        .or('user1_id.eq.$user1,user2_id.eq.$user2,and(user1_id.eq.$user2,user2_id.eq.$user1)')
        .limit(1)
        .maybeSingle();

    if (existingConversationResponse != null && existingConversationResponse['id'] != null) {
      final existingConvoId = existingConversationResponse['id'] as String;
      if (existingConversationResponse['context_offer_id'] != offerId ||
          existingConversationResponse['context_reply_id'] != replyId) {
        await _supabaseClient.from('conversations').update({
          'context_offer_id': offerId,
          'context_reply_id': replyId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existingConvoId);
      }
      final fullConversationData = await _supabaseClient
          .from('conversations')
          .select('*')
          .eq('id', existingConvoId)
          .single();
      final conversation = Conversation.fromMap(fullConversationData, _supabaseClient.auth.currentUser!.id);
      await _cacheService.cacheConversations([conversation]);
      return existingConvoId;
    }

    final UserModel? user1Profile = await _userProfileService.getUserProfile(user1);
    final UserModel? user2Profile = await _userProfileService.getUserProfile(user2);

    final newConversationData = {
      'user1_id': user1,
      'user2_id': user2,
      'context_offer_id': offerId,
      'context_reply_id': replyId,
      'user1_display_name': user1Profile?.username ?? user1,
      'user1_avatar_url': user1Profile?.profilePicture,
      'user2_display_name': user2Profile?.username ?? user2,
      'user2_avatar_url': user2Profile?.profilePicture,
    };

    final response = await _supabaseClient
        .from('conversations')
        .insert(newConversationData)
        .select()
        .single();
    final conversation = Conversation.fromMap(response, _supabaseClient.auth.currentUser!.id);
    await _cacheService.cacheConversations([conversation]);
    return conversation.id;
  }

  // Method to upload an image and return its public URL
  Future<String?> _uploadChatImage(File imageFile, String conversationId, String userId) async {
    try {
      final fileExt = p.extension(imageFile.path).toLowerCase(); // .jpg
      final fileName = '$conversationId/${userId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      
      print("ChatService: Uploading chat image: $fileName to bucket $chatImageBucket");

      await _supabaseClient.storage
          .from(chatImageBucket) // Use constant
          .upload(fileName, imageFile, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
      
      final imageUrlResponse = _supabaseClient.storage
          .from(chatImageBucket) // Use constant
          .getPublicUrl(fileName);
      
      print("ChatService: Chat image uploaded. Public URL: $imageUrlResponse");
      return imageUrlResponse;
    } catch (e) {
      print("ChatService: Error uploading chat image: $e");
      throw Exception("Failed to upload image: ${e.toString()}");
    }
  }

  // Send a text message
  Future<void> sendTextMessage({
    required String conversationId,
    required String senderId,
    required String text,
    String? senderDisplayName,
    String? senderAvatarUrl,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    final tempMessage = ChatMessage(
      id: 'temp_txt_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: senderId,
      messageText: text,
      messageType: messageType ?? 'text',
      createdAt: DateTime.now(),
      senderDisplayName: senderDisplayName ?? senderId,
      senderAvatarUrl: senderAvatarUrl,
      metadata: metadata,
    );
    await _cacheService.addMessageToCache(tempMessage);

    try {
      final messageData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message_text': text,
        'message_type': messageType ?? 'text',
        'sender_display_name': senderDisplayName, // Ensure this is included
        'sender_avatar_url': senderAvatarUrl,   // Ensure this is included
        'metadata': metadata,
      };

      // ***** DEBUG PRINT: ChatService - Before sending to Supabase *****
      print('--- ChatService.sendTextMessage: Data to be sent to Supabase ---');
      print('Conversation ID: ${messageData['conversation_id']}');
      print('Sender ID: ${messageData['sender_id']}');
      print('Message Type: ${messageData['message_type']}');
      print('Metadata being sent: ${messageData['metadata']} (Type: ${messageData['metadata']?.runtimeType})');
      print('Full data object: $messageData');
      // *******************************************************************

      final Map<String, dynamic> supabaseResponse = await _supabaseClient
          .from('chat_messages')
          .insert(messageData)
          .select()
          .single(); // .single() returns a Map<String, dynamic>

      // ***** DEBUG PRINT: ChatService - Supabase Response *****
      print('--- ChatService.sendTextMessage: Response from Supabase ---');
      print('Raw Supabase response map: $supabaseResponse');
      print('Metadata in Supabase response map: ${supabaseResponse['metadata']} (Type: ${supabaseResponse['metadata']?.runtimeType})');
      // *********************************************************

      print('--- ChatService.sendTextMessage: Map being passed to ChatMessage.fromMap ---');
      print('supabaseResponse (as Map<String, dynamic>): $supabaseResponse');
      print('Metadata in supabaseResponse: ${supabaseResponse['metadata']} (Type: ${supabaseResponse['metadata']?.runtimeType})');
      
      final sentMessage = ChatMessage.fromMap(supabaseResponse);
      // ChatMessage.fromMap and ChatMessage constructor will print their own metadata logs now

      print('--- ChatService.sendTextMessage: Parsed ChatMessage object ---');
      print('sentMessage.id: ${sentMessage.id}');
      print('sentMessage.metadata (getter): ${sentMessage.metadata}'); // This uses the getter which decodes JSON
      print('sentMessage.metadataJson (field): ${sentMessage.metadataJson}'); // This is the raw JSON string
      await _cacheService.updateCachedMessageDetails(tempMessage.id, sentMessage.id, sentMessage.imageUrl ?? '');
    } catch (e) {
      print('Error sending text message to Supabase: $e');
      await _cacheService.removeMessageFromCache(tempMessage.id);
      throw Exception('Failed to send text message: $e');
    }

    // Update conversation with last message details
    try {
      String lastMessagePreview = text.trim();
      if (messageType == 'transfer_notification') {
        lastMessagePreview = metadata?['amount'] != null 
          ? "Transfer of ${metadata!['amount']} ${metadata['currency'] ?? 'FCFA'}"
          : "Money transfer notification";
      } else if (messageType == 'image') {
        lastMessagePreview = "Photo"; // This case might be better handled in sendImageMessage
      }

      await _supabaseClient.from('conversations').update({
        'last_message': lastMessagePreview,
        'last_message_sender_id': senderId,
        'last_message_timestamp': DateTime.now().toIso8601String(), 
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      print("ChatService: Error updating conversation after sending message: $e");
      // Non-critical, so don't rethrow, but log it.
    }
  }

  // Send an image message (with optional caption)
  Future<void> sendImageMessage({
    required String conversationId,
    required String senderId,
    required File imageFile,
    String? caption,
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) async {
    final tempMessageId = 'temp_img_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = ChatMessage(
      id: tempMessageId,
      conversationId: conversationId,
      senderId: senderId,
      messageText: caption,
      messageType: 'image',
      imageUrl: imageFile.path,
      createdAt: DateTime.now(),
      senderDisplayName: senderDisplayName ?? senderId,
      senderAvatarUrl: senderAvatarUrl,
    );
    await _cacheService.addMessageToCache(tempMessage);

    try {
      final String fileName = 'chat_attachments/${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
      await _supabaseClient.storage.from('chat_attachments').upload(fileName, imageFile);
      final String publicUrl = _supabaseClient.storage.from('chat_attachments').getPublicUrl(fileName);

      final messageData = {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'message_text': caption,
        'message_type': 'image',
        'image_url': publicUrl,
      };
      final response = await _supabaseClient.from('chat_messages').insert(messageData).select().single();
      // Correct: ChatMessage.fromMap takes one argument
      final sentMessage = ChatMessage.fromMap(Map<String, dynamic>.from(response));
      await _cacheService.updateCachedMessageDetails(tempMessageId, sentMessage.id, publicUrl);
    } catch (e) {
      print('Error sending image message: $e');
      await _cacheService.removeMessageFromCache(tempMessageId);
      throw Exception('Failed to send image message: $e');
    }
  }

  // Method to send a transfer notification message
  Future<void> sendTransferNotificationMessage({
    required String conversationId,
    required String senderId,
    required Map<String, dynamic> transferMetadata, // e.g., {'amount': 1000, 'currency': 'FCFA', 'status': 'completed'}
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) async {
    // For transfer notifications, the main 'text' can be a generic placeholder or derived from metadata
    String notificationText = "Transfer of ${transferMetadata['amount']} ${transferMetadata['currency'] ?? 'FCFA'}.";
    if (transferMetadata['status'] == 'failed') {
       notificationText = "Transfer of ${transferMetadata['amount']} ${transferMetadata['currency'] ?? 'FCFA'} failed.";
    }

    // Call the generalized sendMessage method with messageType 'transfer_notification'
    // The actual display will be handled by the ChatMessageBubble based on type and metadata
    await sendTextMessage(
      conversationId: conversationId,
      senderId: senderId,
      text: notificationText, // This text might be shown as a fallback or in notifications
      senderDisplayName: senderDisplayName,
      senderAvatarUrl: senderAvatarUrl,
      messageType: 'transfer_notification',
      metadata: transferMetadata,
    );
  }

  Stream<List<Conversation>> getConversationsStream(String currentUserId) {
    final cachedStream = _cacheService.watchConversations()
        .doOnData((convos) => print("ChatService: Emitting ${convos.length} convos from cache."));

    // Stream for conversations where current user is user1_id
    final supabaseStreamUser1 = _supabaseClient
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('user1_id', currentUserId)
        .order('last_message_at', ascending: false)
        .map((listOfMaps) => listOfMaps.map((map) => Conversation.fromMap(map, currentUserId)).toList());

    // Stream for conversations where current user is user2_id
    final supabaseStreamUser2 = _supabaseClient
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('user2_id', currentUserId)
        .order('last_message_at', ascending: false)
        .map((listOfMaps) => listOfMaps.map((map) => Conversation.fromMap(map, currentUserId)).toList());

    // Combine the two Supabase streams
    final combinedSupabaseStream = Rx.combineLatest2<List<Conversation>, List<Conversation>, List<Conversation>>(
      supabaseStreamUser1.startWith([]),
      supabaseStreamUser2.startWith([]),
      (list1, list2) {
        final combinedList = <Conversation>[...list1, ...list2];
        // Remove duplicates that might arise if a conversation somehow matches both (should not happen with distinct user1/user2)
        final uniqueList = combinedList.fold<Map<String, Conversation>>({}, (map, convo) {
          map[convo.id] = convo; // Keep last instance by ID
          return map;
        }).values.toList();
        uniqueList.sort((a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(a.lastMessageAt ?? DateTime(0))); // Sort again
        _cacheService.cacheConversations(uniqueList); // Update cache
        return uniqueList;
      }
    ).handleError((error) {
        print("ChatService: Error in combined Supabase conversations stream: $error");
    });
    
    return Rx.combineLatest2<List<Conversation>, List<Conversation>, List<Conversation>>(
      cachedStream.startWith([]),
      combinedSupabaseStream.startWith([]),
      (cached, supabase) {
        if (supabase.isNotEmpty) return supabase;
        return cached;
      }
    ).distinct((prev, next) =>
        prev.length == next.length &&
        prev.every((c) => next.any((n) => n.id == c.id && n.lastMessageAt == c.lastMessageAt && n.lastMessage == c.lastMessage)));
  }

  Stream<List<ChatMessage>> getMessagesStream(String conversationId, String currentUserId) {
    final cachedMessagesStream = Stream.fromFuture(_cacheService.getMessagesForConversation(conversationId))
        .doOnData((messages) => print("ChatService: Emitting ${messages.length} messages from cache for $conversationId"));

    final supabaseMessagesStream = _supabaseClient
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .map((listOfMaps) {
          // Correct: ChatMessage.fromMap takes one argument
          final messages = listOfMaps
              .map((map) => ChatMessage.fromMap(Map<String, dynamic>.from(map)))
              .toList();
          _cacheService.cacheMessages(conversationId, messages);
          return messages;
        })
        .handleError((error) {
          print("ChatService: Error in Supabase messages stream for $conversationId: $error");
        });

    return Rx.combineLatest2<List<ChatMessage>, List<ChatMessage>, List<ChatMessage>>(
      cachedMessagesStream.startWith([]),
      supabaseMessagesStream.startWith([]),
      (cached, supabase) {
        if (supabase.isNotEmpty) return supabase;
        return cached;
      }
    ).distinct((prev, next) =>
        prev.length == next.length &&
        prev.every((m) => next.any((n) => n.id == m.id && n.createdAt.isAtSameMomentAs(m.createdAt))));
  }

  @Deprecated('Use sendTextMessage or sendImageMessage instead')
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String text,
  }) async {
    // This method is now effectively sendTextMessage
    await sendTextMessage(conversationId: conversationId, senderId: senderId, text: text);
  }

  Future<void> markConversationAsRead(String conversationId) async {
    final userId = _supabaseClient.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabaseClient
        .from('conversation_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);
    } catch (e) {
      print("ChatService: Error marking conversation $conversationId as read: $e");
    }
  }

  Future<void> deleteMessage(String messageId, String conversationId) async {
    print("ChatService: Delete message $messageId from $conversationId - Not implemented yet.");
  }

  Future<void> clearChatCache() async {
    await _cacheService.clearAllConversations();
    await _cacheService.clearAllMessages();
    print("ChatService: All chat cache cleared.");
  }
} 