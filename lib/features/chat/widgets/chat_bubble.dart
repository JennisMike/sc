import 'package:flutter/material.dart';
import '../models/chat_message_model.dart'; // Assuming model is in models folder
import 'package:intl/intl.dart'; // For date formatting

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleAlignment = isCurrentUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isCurrentUser ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant;
    final textColor = isCurrentUser ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;
    final borderRadius = isCurrentUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
            topRight: Radius.circular(4), // Small notch for current user
          )
        : const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topLeft: Radius.circular(4), // Small notch for other user
          );

    return Align(
      alignment: bubbleAlignment,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Optionally show sender's name if not current user and in a group chat context
            // if (!isCurrentUser && message.senderDisplayName.isNotEmpty) ...[
            //   Text(
            //     message.senderDisplayName,
            //     style: TextStyle(
            //       fontWeight: FontWeight.bold,
            //       color: textColor.withOpacity(0.8),
            //       fontSize: 12,
            //     ),
            //   ),
            //   const SizedBox(height: 2),
            // ],
            Text(
              message.messageText ?? '' , // Provide an empty string as fallback
              style: TextStyle(color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt), // Simple time format
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 