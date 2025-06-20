import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import '../../../providers/auth_provider.dart';
import '../services/user_profile_service.dart';
import '../../../models/user_model.dart';
import '../services/isar_chat_cache_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/offer_model.dart';
import '../../../models/reply_model.dart';

// Define a type alias for the tuple for clarity
typedef ConversationMessagesArgs = (String conversationId, String currentUserId);

// Provider for ChatService instance
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(isarChatCacheServiceProvider));
});

// Provider for UserProfileService instance
final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService();
});

// Provider for IsarChatCacheService
final isarChatCacheServiceProvider = Provider<IsarChatCacheService>((ref) {
  return IsarChatCacheService();
});

// FutureProvider.family to get a specific user's profile by ID
final userProfileProviderFamily = FutureProvider.autoDispose.family<UserModel?, String>((ref, userId) async {
  final userProfileService = ref.watch(userProfileServiceProvider);
  return userProfileService.getUserProfile(userId);
});

// Stream provider for a list of conversations for the current user
final conversationsStreamProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  
  // Attempt to get currentUserId from authRepositoryProvider first
  String? currentUserId = ref.watch(authRepositoryProvider).value?.user?.id;

  // If still null (e.g., provider is loading or hasn't processed local session yet),
  // try getting it directly from Supabase's current session (local cache).
  if (currentUserId == null) {
    currentUserId = Supabase.instance.client.auth.currentSession?.user.id;
    print("conversationsStreamProvider: authRepositoryProvider gave null ID, trying direct Supabase session. UserID: $currentUserId");
  }

  if (currentUserId == null) {
    print("conversationsStreamProvider: No current user ID after all checks, returning empty stream.");
    return Stream.value([]);
  }
  print("conversationsStreamProvider: Subscribing for user ID: $currentUserId");
  return chatService.getConversationsStream(currentUserId);
});

// Updated Provider to stream messages for a specific conversation and user
final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, ConversationMessagesArgs>((ref, args) {
  final chatService = ref.watch(chatServiceProvider);
  final conversationId = args.$1;
  final currentUserId = args.$2;

  if (conversationId.isEmpty) {
    print("messagesStreamProvider: conversationId is empty, returning empty stream.");
    return Stream.value([]);
  }
  if (currentUserId.isEmpty || currentUserId == 'loading' || currentUserId == 'initial') {
     print("messagesStreamProvider: currentUserId is invalid ($currentUserId), returning empty stream temporarily.");
    return Stream.value([]); // Don't fetch if user ID is not valid yet
  }
  return chatService.getMessagesStream(conversationId, currentUserId);
});

// Provider to potentially hold the currently active conversation ID
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// Provider to fetch a single conversation by ID
final conversationProviderFamily = FutureProvider.autoDispose.family<Conversation?, String>((ref, conversationId) async {
  // This is a simplified example. You might need a dedicated method in ChatService 
  // to fetch a single conversation, or you could filter the list from conversationsStreamProvider.
  // For now, let's assume ChatService gets a method or we adapt.
  // If using Supabase directly:
  try {
    final data = await Supabase.instance.client
        .from('conversations')
        .select('''
              id,
              user1_id,
              user2_id,
              context_offer_id,
              context_reply_id,
              last_message_text,
              last_message_at,
              last_message_sender_id,
              created_at,
              updated_at,
              user1_display_name,
              user1_avatar_url,
              user2_display_name,
              user2_avatar_url,
              user1_profile:profiles!conversations_user1_id_fkey (id, username, profile_picture),
              user2_profile:profiles!conversations_user2_id_fkey (id, username, profile_picture)
            ''')
        .eq('id', conversationId)
        .maybeSingle();
    if (data != null) {
      String? currentUserId = ref.watch(authRepositoryProvider).value?.user?.id ?? Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return null; // Cannot determine other user without current user context
      return Conversation.fromMap(data, currentUserId);
    }
    return null;
  } catch (e) {
    print("Error fetching conversation $conversationId: $e");
    return null;
  }
});

// Provider to fetch a single offer by ID
final offerByIdProviderFamily = FutureProvider.autoDispose.family<Offer?, String>((ref, offerId) async {
  if (offerId.isEmpty) return null;
  try {
    final data = await Supabase.instance.client
        .from('offers')
        .select('*')
        .eq('id', offerId)
        .single();
    return Offer.fromMap(data);
  } catch (e) {
    print("Error fetching offer $offerId: $e");
    return null;
  }
});

// Provider to fetch a single reply by ID
final replyByIdProviderFamily = FutureProvider.autoDispose.family<Reply?, String>((ref, replyId) async {
  if (replyId.isEmpty) return null;
  try {
    final data = await Supabase.instance.client
        .from('replies')
        .select('*')
        .eq('id', replyId)
        .single();
    return Reply.fromMap(data);
  } catch (e) {
    print("Error fetching reply $replyId: $e");
    return null;
  }
});