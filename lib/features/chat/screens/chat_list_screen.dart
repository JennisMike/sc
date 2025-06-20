import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../models/conversation_model.dart';
import './individual_chat_screen.dart';
import '../../../providers/auth_provider.dart'; // For current user ID
import 'package:intl/intl.dart'; // For date formatting
// No need to import UserModel here if we primarily use Conversation model's data first

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsyncValue = ref.watch(conversationsStreamProvider);
    final currentUserId = ref.watch(authRepositoryProvider).value?.user?.id;

    return Scaffold(
      body: conversationsAsyncValue.when(
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Text('No chats yet. Start a conversation!'), // Simplified message
            );
          }
          if (currentUserId == null) {
            // This state should be brief as provider depends on auth state
            return const Center(child: Text('Waiting for user...')); 
          }

          return ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final otherUserId = conversation.getOtherUserId(currentUserId!);
              
              // Get initial display data directly from the conversation object (cached)
              String displayName = conversation.getOtherUserDisplayName(currentUserId);
              String avatarUrl = conversation.getOtherUserAvatarUrl(currentUserId);
              final String displayChar = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

              // Attempt to get fresh profile data for potential UI update,
              // but don't let its loading/error state block the list item rendering.
              // The `userProfileProviderFamily` will trigger a rebuild of this specific item if it gets new data.
              final otherUserProfileAsync = ref.watch(userProfileProviderFamily(otherUserId));
              otherUserProfileAsync.whenData((profile) {
                if (profile != null) {
                  // If fresh profile data is different, update the local vars for this build.
                  // This will cause a targeted rebuild of this list item if values change.
                  final newDisplayName = profile.username ?? displayName;
                  final newAvatarUrl = profile.profilePicture ?? avatarUrl;
                  if (newDisplayName != displayName || newAvatarUrl != avatarUrl) {
                    // Note: This direct update inside `whenData` is for the current build pass.
                    // For subsequent rebuilds triggered by the provider, this list item widget
                    // will get the new values directly when `ref.watch` is called again for userProfileProviderFamily.
                    // For this to reflect immediately if the list is not rebuilt by other means,
                    // you might need a StatefulWidget for the list item, or ensure this component rebuilds.
                    // However, Riverpod's ref.watch should handle rebuilding this specific item.
                    displayName = newDisplayName;
                    avatarUrl = newAvatarUrl;
                  }
                }
              });

              final lastMessage = conversation.lastMessage ?? 'No messages yet.';
              final lastMessageTime = conversation.lastMessageAt != null
                  ? DateFormat('HH:mm').format(conversation.lastMessageAt!)
                  : '';
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty ? Text(displayChar) : null,
                ),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  conversation.lastMessageSenderId == currentUserId 
                    ? 'You: $lastMessage' 
                    : lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(lastMessageTime),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => IndividualChatScreen(
                        conversationId: conversation.id,
                        otherUserId: otherUserId,
                        otherUserDisplayName: displayName, // Pass the most up-to-date name
                        otherUserAvatarUrl: avatarUrl,     // Pass the most up-to-date avatar
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()), // This is for the conversationsStreamProvider itself
        error: (error, stack) {
          print("ChatListScreen: Error loading conversations stream: $error\n$stack");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Error loading chats. Please try again.'),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: () => ref.refresh(conversationsStreamProvider),
                    child: const Text('Retry'))
              ],
            ),
          );
        },
      ),
    );
  }
} 