import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reply_model.dart';
// import '../app/app_theme.dart'; // Removed - will use Theme.of(context)

class ReplyBubble extends StatelessWidget {
  final Reply reply;
  final String offerType; // To format the reply message correctly
  final bool isOfferOwner; // Added: True if the current user owns the offer this reply is for
  final VoidCallback? onAcceptReply; // Added: Callback when offer owner accepts this reply
  final bool isOfferAccepted; // New field: To know if the parent offer has been accepted

  const ReplyBubble({
    super.key,
    required this.reply,
    required this.offerType,
    required this.isOfferOwner,
    this.onAcceptReply,
    required this.isOfferAccepted, // Make it required
  });

  @override
  Widget build(BuildContext context) {
    String replyMessage;
    if (offerType == 'RMB available') {
      replyMessage = 'Wants to give: ${NumberFormat("#,##0").format(reply.amount)} FCFA at your rate';
    } else {
      replyMessage = 'Offers rate: ${reply.rate}%';
    }

    return Container(
      margin: const EdgeInsets.only(left: 50, right: 10, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200], // Always use the default color
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(12),
        ),
        // border: null, // No special border for accepted status
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 10,
                backgroundImage: reply.userAvatarUrl.isNotEmpty
                    ? NetworkImage(reply.userAvatarUrl)
                    : null,
                child: reply.userAvatarUrl.isEmpty
                    ? Text(reply.userDisplayName.isNotEmpty ? reply.userDisplayName[0] : 'U', style: const TextStyle(fontSize: 10))
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reply.userDisplayName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!reply.isPublic)
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(Icons.visibility_off, color: Colors.grey[600], size: 14),
                ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(reply.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(replyMessage, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13)),
          if (reply.status == 'accepted')
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Chip(
                label: const Text('Accepted'),
                backgroundColor: Colors.green.withOpacity(0.1),
                labelStyle: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold, fontSize: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          if (isOfferOwner && reply.status == 'pending' && !isOfferAccepted && onAcceptReply != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Accept'),
                onPressed: onAcceptReply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
          // If the offer is accepted, and this reply is NOT the accepted one, and it was pending, show disabled text
          if (isOfferAccepted && reply.status == 'pending' && isOfferOwner)
             Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Offer already accepted',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).disabledColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 