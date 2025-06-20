import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import ConsumerWidget and WidgetRef
import 'package:cached_network_image/cached_network_image.dart'; // Import cached_network_image
import '../models/chat_message_model.dart';
import '../providers/chat_providers.dart'; // Import userProfileProviderFamily
import 'dart:convert'; // For jsonDecode
import '../../../models/user_model.dart'; // Import UserModel
import '../../../providers/auth_provider.dart'; // Import authRepositoryProvider
import 'package:intl/intl.dart';
import './full_screen_image_viewer.dart'; // Import the new screen

class ChatMessageBubble extends ConsumerWidget {
  // Changed to ConsumerWidget
  final ChatMessage message;
  final bool isCurrentUser;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  // Helper method to build the transfer notification bubble
  Widget _buildTransferNotificationBubble(BuildContext context, ThemeData theme,
      ChatMessage message, String? currentAuthUserId) {
    // Debug: Print the raw metadata before decoding
    print('--- ChatMessageBubble: Raw metadata before decoding ---');
    print('message.metadata type: ${message.metadata.runtimeType}');
    print('message.metadata value: ${message.metadata}');
    print('message.metadataJson: ${message.metadataJson}');

    Map<String, dynamic> metadata;
    try {
      // If metadata is already a Map, use it directly; otherwise try to decode from string
      if (message.metadata is Map<String, dynamic>) {
        metadata = message.metadata as Map<String, dynamic>;
        print('--- ChatMessageBubble: Metadata is already a Map ---');
      } else {
        metadata = jsonDecode((message.metadata as String?) ?? '{}')
            as Map<String, dynamic>;
        print('--- ChatMessageBubble: Metadata decoded from String ---');
      }
      print('--- ChatMessageBubble: Decoded metadata ---');
      print('amount: ${metadata['amount']}');
      print('currency: ${metadata['currency']}');
      print('sender_name: ${metadata['sender_name']}');
      print('receiver_name: ${metadata['receiver_name']}');
    } catch (e) {
      print('Error decoding message metadata for message ID ${message.id}: $e');
      metadata =
          {}; // Default to an empty map if decoding fails, preventing a crash
    }
    // Handle different possible types for amount (int, double, String, etc.)
    num rawAmount;
    try {
      if (metadata['amount'] is num) {
        rawAmount = metadata['amount'] as num;
      } else if (metadata['amount'] is String) {
        rawAmount = double.tryParse(metadata['amount'] as String) ?? 0.0;
      } else {
        rawAmount = 0.0;
      }
      print('--- ChatMessageBubble: Extracted amount: $rawAmount ---');
    } catch (e) {
      print('Error extracting amount from metadata: $e');
      rawAmount = 0.0;
    }
    final amount = rawAmount.toDouble();
    final currency = metadata['currency'] as String? ?? 'FCFA';
    final bool isSenderOfTransfer =
        currentAuthUserId != null && message.senderId == currentAuthUserId;
    final String? receiverName = metadata['receiver_name'] as String?;
    final String? senderName = metadata['sender_name'] as String?;

    String transferMessageText;
    IconData transferIcon =
        Icons.check_circle_outline_rounded; // Default to success icon
    // Define Alipay-inspired orange color for transfer notifications
    const Color alipayOrange = Color(0xFFF5A623); // Bright orange color inspired by Alipay
    const Color alipayOrangeLight = Color(0xFFFFF8E7); // Light orange background
    const Color alipayOrangeDark = Color(0xFF8A5D00); // Dark orange text
    
    Color iconColor = alipayOrange; // Use Alipay orange for icon
    Color bubbleColor = alipayOrangeLight; // Use light orange for bubble background
    Color textColor = alipayOrangeDark; // Use dark orange for text

    if (isSenderOfTransfer) {
      transferMessageText =
          "You transferred ${amount.toStringAsFixed(0)} $currency to ${receiverName ?? 'recipient'}";
    } else {
      transferMessageText =
          "You received ${amount.toStringAsFixed(0)} $currency from ${senderName ?? 'Someone'}";
    }

    return Align(
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: bubbleColor, // Use defined bubbleColor
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(transferIcon, color: iconColor, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    transferMessageText,
                    style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        fontWeight: FontWeight.w500), // Use defined textColor
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Text(
                DateFormat('HH:mm').format(message.createdAt.toLocal()),
                style: TextStyle(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onTertiaryContainer.withOpacity(0.6)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Added WidgetRef
    final theme = Theme.of(context);
    final align = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isCurrentUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceVariant;
    final textColor = isCurrentUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final AsyncValue<UserModel?>? senderProfileAsync = isCurrentUser
        ? null
        : ref.watch(userProfileProviderFamily(message.senderId));

    // Initialize with values from message, provide strong fallbacks
    String displayName = message
        .senderDisplayName; // Already falls back to senderId in ChatMessageModel
    String? avatarUrl = message.senderAvatarUrl;

    if (!isCurrentUser && senderProfileAsync != null) {
      senderProfileAsync.whenData((profile) {
        if (profile != null) {
          displayName = profile.username ??
              displayName; // Prefer fetched username, else keep original (which has fallback)
          avatarUrl = profile.profilePicture ??
              avatarUrl; // Prefer fetched avatar, else keep original
        }
      });
    }

    // Ensure displayName has a non-empty value for avatar fallback char
    final String displayChar =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    final bool isImageMessage = message.messageType == 'image' &&
        message.imageUrl != null &&
        message.imageUrl!.isNotEmpty;
    final String heroTag =
        'chat_image_${message.id}'; // Unique tag for Hero animation

    final bool isTransferNotification =
        message.messageType == 'transfer_notification';

    if (isTransferNotification) {
      final currentAuthUserId =
          ref.watch(authRepositoryProvider).value?.user?.id;
      return _buildTransferNotificationBubble(
          context, theme, message, currentAuthUserId);
    } else {
      return Align(
        alignment: align,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: isImageMessage
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8), // No padding for image container
          decoration: BoxDecoration(
            color: isImageMessage
                ? Colors.transparent
                : bubbleColor, // Transparent for image only messages
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width *
                0.75, // Max width for bubbles
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser &&
                  !isImageMessage) // Show sender display name only for non-image messages by others
                Padding(
                  padding: const EdgeInsets.only(
                      bottom: 2.0, left: 2.0), // Adjust padding as needed
                  child: Text(
                    displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.8)),
                  ),
                ),

              if (isImageMessage)
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return FullScreenImageViewerScreen(
                          imageUrl: message.imageUrl!, heroTag: heroTag);
                    }));
                  },
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width *
                              0.5, // Reduce max width for image specifically
                          maxHeight: 100, // Reduce max height further
                        ),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CachedNetworkImage(
                              imageUrl: message.imageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              progressIndicatorBuilder: (BuildContext context, String url, DownloadProgress downloadProgress) =>
                                  Center(child: CircularProgressIndicator(value: downloadProgress.progress, color: theme.colorScheme.primary)),
                              errorWidget: (BuildContext context, String url, dynamic error) => Container(
                                color: theme.colorScheme.errorContainer,
                                child: Center(
                                  child: Icon(Icons.broken_image, color: theme.colorScheme.onErrorContainer, size: 40),
                                ),
                              ),
                            ),
                            // Display timestamp directly on the image
                            Container(
                              margin: const EdgeInsets.all(6.0),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.scrim.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                              child: Text(
                                DateFormat('HH:mm')
                                    .format(message.createdAt.toLocal()),
                                style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Display caption (messageText) if it exists, for image or text messages
              if (message.messageText != null &&
                  message.messageText!.isNotEmpty)
                Padding(
                  // Add padding if it's an image message with text, else default padding is handled by container
                  padding: isImageMessage
                      ? const EdgeInsets.only(
                          top: 6.0, left: 8.0, right: 8.0, bottom: 4.0)
                      : EdgeInsets.zero,
                  child: Text(
                    message.messageText!,
                    style: TextStyle(
                        color: isImageMessage
                            ? Theme.of(context).colorScheme.onBackground
                            : textColor,
                        fontSize:
                            16), // Different text color for captions on images
                  ),
                ),

              // Timestamp for text-only messages (or if caption is very short and no image)
              // If it's an image, timestamp is already on the image.
              // If it's text-only OR an image with a caption, and the caption is the only content in this part.
              if (!isImageMessage &&
                  (message.messageText != null &&
                      message.messageText!.isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(
                      top: 4.0), // Only add top padding if there's text above
                  child: Text(
                    DateFormat('HH:mm').format(message.createdAt.toLocal()),
                    style: TextStyle(
                        fontSize: 10, color: textColor.withOpacity(0.7)),
                    textAlign: isCurrentUser ? TextAlign.right : TextAlign.left,
                  ),
                ),
            ],
          ),
        ),
      ); // End of Align widget for transfer notification
    }
  }
}
