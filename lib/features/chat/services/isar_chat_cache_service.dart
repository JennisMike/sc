import 'package:isar/isar.dart';
import 'package:swap_chat_leancloud/features/chat/models/conversation_model.dart';
import 'package:swap_chat_leancloud/features/chat/models/chat_message_model.dart';
import 'package:swap_chat_leancloud/main.dart'; // To access globalIsarInstance

class IsarChatCacheService {
  Isar get _isar => globalIsarInstance;

  /// Caches a list of conversations.
  /// Replaces existing conversations with the same Supabase ID (due to @Index(unique: true, replace: true) on Conversation.id).
  Future<void> cacheConversations(List<Conversation> conversations) async {
    await _isar.writeTxn(() async {
      await _isar.conversations.putAll(conversations);
    });
  }

  /// Retrieves all cached conversations, ordered by last message time (descending).
  Future<List<Conversation>> getAllConversations() async {
    return await _isar.conversations
        .where()
        .sortByLastMessageAtDesc()
        .findAll();
  }

  /// Watches for changes in the cached conversations.
  /// Emits a new list of conversations whenever the cache changes.
  /// Ordered by last message time (descending).
  Stream<List<Conversation>> watchConversations() {
    // The generated .g.dart file provides the necessary query builders.
    return _isar.conversations
        .where()
        .sortByLastMessageAtDesc()
        .watch(fireImmediately: true);
  }

  /// Retrieves a single conversation by its Supabase ID.
  Future<Conversation?> getConversationBySupabaseId(String supabaseId) async {
    // Assuming the generated query for 'id' (Supabase ID) is available.
    // Typically, it would be something like .idEqualTo() or via .filter().
    // If `conversation_model.g.dart` generated `idEqualTo`, this will work.
    return await _isar.conversations.filter().idEqualTo(supabaseId).findFirst();
  }
  
  /// Clears all conversations from the cache.
  Future<void> clearAllConversations() async {
    await _isar.writeTxn(() async {
      await _isar.conversations.clear(); // Clears the entire collection
    });
  }

  /// Deletes a single conversation from cache by its Supabase ID.
  Future<void> deleteConversationBySupabaseId(String supabaseId) async {
    await _isar.writeTxn(() async {
      // First, find the Isar internal ID (isarId) using the Supabase ID (id)
      final conversationToDelete = await _isar.conversations
          .filter()
          .idEqualTo(supabaseId) // Use generated filter for the 'id' field
          .findFirst();

      if (conversationToDelete != null) {
        // Use the internal isarId to delete
        await _isar.conversations.delete(conversationToDelete.isarId);
      }
    });
  }

  // --- ChatMessage Caching Methods ---

  /// Caches a list of messages.
  /// Replaces existing messages with the same Supabase ID.
  Future<void> cacheMessages(String conversationId, List<ChatMessage> messages) async {
    await _isar.writeTxn(() async {
      // Clear existing messages for this conversation first to prevent duplicates if IDs change or for simplicity
      // This is a simple strategy. A more complex one could involve diffing.
      final existingMessages = await _isar.chatMessages.filter().conversationIdEqualTo(conversationId).findAll();
      await _isar.chatMessages.deleteAll(existingMessages.map((m) => m.isarId).toList());
      await _isar.chatMessages.putAll(messages);
    });
  }

  /// Retrieves all cached messages for a given conversation, ordered by creation time (ascending).
  Future<List<ChatMessage>> getMessagesForConversation(String conversationId) async {
    return await _isar.chatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .findAll();
  }

  /// Watches for changes in cached messages for a specific conversation.
  /// Emits a new list of messages whenever the cache changes for that conversation.
  /// Ordered by creation time (ascending).
  Stream<List<ChatMessage>> watchMessagesForConversation(String conversationId) {
    return _isar.chatMessages
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }
  
  /// Adds a single message to the cache.
  Future<void> addMessageToCache(ChatMessage message) async {
    await _isar.writeTxn(() async {
      await _isar.chatMessages.put(message);
    });
  }

  /// Clears all messages for a specific conversation from the cache.
  Future<void> clearMessagesForConversation(String conversationId) async {
    await _isar.writeTxn(() async {
      // Find all messages for the conversation
      final messagesToDelete = await _isar.chatMessages
          .filter()
          .conversationIdEqualTo(conversationId)
          .findAll();
      
      // Get their Isar IDs
      final List<int> isarIdsToDelete = messagesToDelete.map((m) => m.isarId).toList();
      
      if (isarIdsToDelete.isNotEmpty) {
        await _isar.chatMessages.deleteAll(isarIdsToDelete);
      }
    });
  }

  /// Clears all chat messages from the cache.
  Future<void> clearAllMessages() async {
    await _isar.writeTxn(() async {
      await _isar.chatMessages.clear();
    });
  }

  /// New method to update a cached message's Supabase ID and Image URL after successful send
  Future<void> updateCachedMessageDetails(String tempMessageId, String finalMessageId, String finalImageUrl) async {
    await _isar.writeTxn(() async {
      final messageToUpdate = await _isar.chatMessages.filter().idEqualTo(tempMessageId).findFirst();
      if (messageToUpdate != null) {
        // Create a new ChatMessage instance with all fields from messageToUpdate, then override specific ones.
        final updatedMessage = ChatMessage(
          // Do not pass isarId to the constructor
          id: finalMessageId, // New Supabase ID
          conversationId: messageToUpdate.conversationId,
          senderId: messageToUpdate.senderId,
          senderDisplayName: messageToUpdate.senderDisplayName,
          senderAvatarUrl: messageToUpdate.senderAvatarUrl,
          messageText: messageToUpdate.messageText,
          createdAt: messageToUpdate.createdAt, 
          messageType: messageToUpdate.messageType,
          imageUrl: finalImageUrl, // New image URL
        );
        // Manually set the isarId on the new instance to ensure Isar updates the correct object
        updatedMessage.isarId = messageToUpdate.isarId; 
        await _isar.chatMessages.put(updatedMessage);
      }
    });
  }

  /// New method to remove a message from cache by its Supabase ID
  Future<void> removeMessageFromCache(String messageId) async {
    await _isar.writeTxn(() async {
      final messageToDelete = await _isar.chatMessages.filter().idEqualTo(messageId).findFirst();
      if (messageToDelete != null) {
        await _isar.chatMessages.delete(messageToDelete.isarId);
      }
    });
  }
}

// Removed custom extensions as Isar generator should provide them if fields are indexed.
// Ensure `id` field in `Conversation` model is properly indexed for efficient querying.
// The `@Index(unique: true, replace: true)`