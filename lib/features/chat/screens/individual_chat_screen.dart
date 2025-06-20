import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // For ImagePicker
import '../../../models/user_model.dart'; // Import UserModel
import '../models/chat_message_model.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_message_bubble.dart';
import '../../../providers/auth_provider.dart';
import './transfer_money_screen.dart'; // Import the new screen

class IndividualChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserDisplayName;
  final String? otherUserAvatarUrl;

  const IndividualChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserDisplayName,
    this.otherUserAvatarUrl,
  });

  @override
  ConsumerState<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends ConsumerState<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<File?> _selectedImageFileNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isSendingNotifier = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      // Rebuilds send button via ValueListenableBuilder
    });
    // Fetch initial messages if needed, or rely on stream
    // Potentially mark conversation as read here
    ref.read(chatServiceProvider).markConversationAsRead(widget.conversationId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _selectedImageFileNotifier.dispose();
    _isSendingNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        _selectedImageFileNotifier.value = File(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _clearSelectedImage() {
    _selectedImageFileNotifier.value = null;
  }

  Future<void> _sendMessage() async {
    final authState = ref.read(authRepositoryProvider).value;
    final UserModel? currentUser = authState?.user;

    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot send message: User not authenticated.')),
        );
      }
      return;
    }

    final chatService = ref.read(chatServiceProvider);
    final caption = _messageController.text.trim();
    final File? imageFile = _selectedImageFileNotifier.value;

    if (imageFile != null) {
      _isSendingNotifier.value = true;
      _messageController.clear();
      _selectedImageFileNotifier.value = null;

      try {
        await chatService.sendImageMessage(
          conversationId: widget.conversationId,
          senderId: currentUser.id,
          imageFile: imageFile, 
          caption: caption.isNotEmpty ? caption : null,
          senderDisplayName: currentUser.username,      
          senderAvatarUrl: currentUser.profilePicture,  
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send image: $e')),
          );
        }
      } finally {
        if (mounted) {
          _isSendingNotifier.value = false;
        }
      }
    } else {
      if (caption.isEmpty) return;
      
      String textToSend = caption;
      _messageController.clear();

      try {
        await chatService.sendTextMessage(
          conversationId: widget.conversationId,
          senderId: currentUser.id,
          text: textToSend,
          senderDisplayName: currentUser.username,      
          senderAvatarUrl: currentUser.profilePicture,  
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
          _messageController.text = textToSend;
        }
      }
    }
  }
  
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) { 
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent, // Corrected to minScrollExtent for reverse: true
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAuthData = ref.watch(authRepositoryProvider).value;
    final currentUserId = currentAuthData?.user?.id;
    
    final messagesAsyncValue = ref.watch(messagesStreamProvider((widget.conversationId, currentUserId ?? 'loading')));

    // No longer watching conversationProviderFamily, offerByIdProviderFamily, or replyByIdProviderFamily here
    // as the context is now part of the chat messages.

    ref.listen(messagesStreamProvider((widget.conversationId, currentUserId ?? 'initial')), (previous, next) {
       if (next.hasValue && next.value!.isNotEmpty) {
         _scrollToBottom();
       }
       // When new messages arrive, mark conversation as read again
       if (next.hasValue) {
         ref.read(chatServiceProvider).markConversationAsRead(widget.conversationId);
       }
     });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Consumer(builder: (context, ref, child) {
              final otherUserProfileAsync = ref.watch(userProfileProviderFamily(widget.otherUserId));
              String displayName = widget.otherUserDisplayName;
              String? avatarUrl = widget.otherUserAvatarUrl;

              otherUserProfileAsync.whenData((profile) {
                if (profile != null) {
                  displayName = profile.username ?? widget.otherUserDisplayName;
                  avatarUrl = profile.profilePicture ?? widget.otherUserAvatarUrl;
                }
              });
              
              final String displayChar = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

              return Row(
                // mainAxisSize: MainAxisSize.min, // Removed to fix lint: The named parameter 'mainAxisSize' isn't defined.
                children: [
                  CircleAvatar(
                    backgroundImage: (avatarUrl?.isNotEmpty == true) 
                        ? NetworkImage(avatarUrl!) // Safe due to isNotEmpty check
                        : null,
                    backgroundColor: (avatarUrl?.isNotEmpty == true) 
                        ? Colors.transparent // Or use a placeholder color from theme if background shows through
                        : Theme.of(context).colorScheme.primaryContainer,
                    radius: 20,
                    child: (avatarUrl?.isNotEmpty == true) 
                        ? null 
                        : Text(displayChar, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  Text(displayName, style: const TextStyle(fontSize: 16)),
                ],
              );
            }),
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String result) {
              switch (result) {
                case 'transfer_fcfa':
                  // Navigate to TransferMoneyScreen (to be created)
                  // Fetch latest recipient details for accuracy
                  final otherUserProfile = ref.read(userProfileProviderFamily(widget.otherUserId)).value;
                  final recipientDisplayName = otherUserProfile?.username ?? widget.otherUserDisplayName;
                  final recipientAvatarUrl = otherUserProfile?.profilePicture ?? widget.otherUserAvatarUrl;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TransferMoneyScreen(
                        recipientId: widget.otherUserId,
                        recipientDisplayName: recipientDisplayName,
                        recipientAvatarUrl: recipientAvatarUrl,
                        conversationId: widget.conversationId, // Pass the conversationId
                      ),
                    ),
                  );
                  break;
                case 'view_profile':
                  // Navigate to other user's profile screen
                  // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfileScreen(userId: widget.otherUserId)));
                  print('Navigate to View Profile screen for ${widget.otherUserId}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View Profile selected (Screen TBD)')),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'transfer_fcfa',
                child: Text('Transfer FCFA'),
              ),
              const PopupMenuItem<String>(
                value: 'view_profile',
                child: Text('View Profile'),
              ),
              // Add other options like 'Block User', 'Report User' later
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Removed the pinned context UI block that was here
          Expanded(
            child: messagesAsyncValue.when(
              data: (messages) {
                if (currentUserId == null || currentUserId == 'loading') {
                  return const Center(child: CircularProgressIndicator(key: ValueKey("auth_loading")));
                }
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say something!', key: ValueKey("no_messages")));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Keep reverse true for chat UIs
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final bool isCurrentUser = message.senderId == currentUserId;
                    return ChatMessageBubble(
                      key: ValueKey(message.id), 
                      message: message,
                      isCurrentUser: isCurrentUser,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(key: ValueKey("messages_loading"))),
              error: (error, stack) {
                print("IndividualChatScreen: Error loading messages: $error\n$stack");
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error loading messages.'),
                      ElevatedButton(
                        onPressed: () {
                           if (currentUserId != null && currentUserId != 'loading') {
                             ref.refresh(messagesStreamProvider((widget.conversationId, currentUserId)));
                           }
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  )
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<File?>(
                  valueListenable: _selectedImageFileNotifier,
                  builder: (context, imageFile, child) {
                    if (imageFile == null) return const SizedBox.shrink();
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 100,
                              maxWidth: MediaQuery.of(context).size.width * 0.5,
                            ),
                            child: Image.file(imageFile, fit: BoxFit.contain),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                          onPressed: _clearSelectedImage,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.photo_camera, color: Theme.of(context).colorScheme.primary),
                      onPressed: _pickImage, // Restored onPressed
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(30)),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceVariant, // Or surface
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _isSendingNotifier,
                      builder: (context, isSending, child) {
                        return ValueListenableBuilder<File?>(
                          valueListenable: _selectedImageFileNotifier,
                          builder: (context, imageFile, child) {
                            // Use ValueListenableBuilder for _messageController to react to text changes for canSend state
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _messageController,
                              builder: (context, messageValue, child) {
                                final bool canSend = (messageValue.text.trim().isNotEmpty || imageFile != null);
                                return IconButton(
                                  icon: isSending
                                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                                      : Icon(Icons.send, color: canSend ? Theme.of(context).colorScheme.primary : Theme.of(context).disabledColor),
                                  onPressed: (isSending || !canSend) ? null : _sendMessage,
                                );
                              }
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 