import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/offer_model.dart';
import '../models/reply_model.dart';
import '../features/chat/providers/chat_providers.dart';
import '../providers/reply_provider.dart';
import './reply_bubble.dart';
import 'package:intl/intl.dart';
import './offer_action_box.dart';

class OfferBubble extends ConsumerWidget {
  final Offer offer;
  final bool isMine;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final Function(Offer offer, Reply reply)? onAcceptOfferReply;

  const OfferBubble({
    super.key,
    required this.offer,
    required this.isMine,
    this.onDelete,
    this.onReply,
    this.onAcceptOfferReply,
  });

  void _showActionBox(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset position = box.localToGlobal(Offset.zero);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black12),
            ),
          ),
          Positioned(
            left: isMine ? null : 12,
            right: isMine ? 12 : null,
            bottom: MediaQuery.of(context).size.height -
                position.dy -
                box.size.height,
            width: 150,
            child: OfferActionBox(
              isOwner: isMine,
              offerStatus: offer.status,
              onDelete: onDelete,
              onReply: onReply,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool isOfferEffectivelyAccepted = offer.status == 'accepted';

    final bool needsProfileFetch = !isMine && (offer.userAvatarUrl.isEmpty || offer.userDisplayName == offer.userId);
    final offerUserProfileAsync = needsProfileFetch 
        ? ref.watch(userProfileProviderFamily(offer.userId))
        : null;

    String finalDisplayName = offer.userDisplayName;
    String finalAvatarUrl = offer.userAvatarUrl;

    if (offerUserProfileAsync != null) {
      offerUserProfileAsync.whenData((profile) {
        if (profile != null) {
          finalDisplayName = profile.username ?? offer.userDisplayName;
          finalAvatarUrl = profile.profilePicture ?? offer.userAvatarUrl;
        }
      });
    }
    
    final String displayChar = finalDisplayName.isNotEmpty && finalDisplayName != offer.userId 
                              ? finalDisplayName[0].toUpperCase() 
                              : (offer.userId.isNotEmpty ? offer.userId[0].toUpperCase() : "?");

    final replyService = ref.watch(supabaseReplyServiceProvider);

    final Color userBubbleColorLight = theme.colorScheme.primaryContainer;
    final Color userBubbleColorDark = const Color.fromARGB(255, 42, 56, 157);
    final Color otherBubbleColorLight = theme.colorScheme.surfaceVariant;
    final Color otherBubbleColorDark = Colors.grey.shade800;
    final Color userBubbleTextColorLight = theme.colorScheme.onPrimaryContainer;
    final Color userBubbleTextColorDark = Colors.white;
    final Color otherBubbleTextColorLight = theme.colorScheme.onSurfaceVariant;
    final Color otherBubbleTextColorDark = Colors.white;

    final bubbleColor = isMine
        ? (isDark ? userBubbleColorDark : userBubbleColorLight)
        : (isDark ? otherBubbleColorDark : otherBubbleColorLight);
    final textColor = isMine
        ? (isDark ? userBubbleTextColorDark : userBubbleTextColorLight)
        : (isDark ? otherBubbleTextColorDark : otherBubbleTextColorLight);

    final displayNameColor = isDark ? Colors.grey.shade300 : theme.colorScheme.primary;
    final avatarBackgroundColor = isDark ? Colors.grey.shade700 : theme.colorScheme.secondaryContainer;
    final avatarForegroundColor = isDark ? Colors.white : theme.colorScheme.onSecondaryContainer;
    final rateBadgeBackgroundColorIsMine = isDark
        ? Colors.white.withOpacity(0.20)
        : theme.colorScheme.surface.withOpacity(0.2);
    final rateBadgeBackgroundColorOther = isDark
        ? Colors.grey.shade700
        : theme.colorScheme.secondaryContainer.withOpacity(0.5);
    final rateBadgeTextColorIsMine =
        isDark ? Colors.white.withOpacity(0.85) : theme.colorScheme.onSurface;
    final rateBadgeTextColorOther =
        isDark ? Colors.grey.shade200 : theme.colorScheme.onSecondaryContainer;
    final timestampColorIsMine = isDark
        ? Colors.white.withOpacity(0.7)
        : theme.textTheme.bodySmall?.color?.withOpacity(0.7);
    final timestampColorOther = isDark
        ? Colors.grey.shade400
        : theme.textTheme.bodySmall?.color?.withOpacity(0.7);

    final align = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final borderRadius = isMine
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          );

    return GestureDetector(
      onLongPress: () => _showActionBox(context),
      child: Opacity(
        opacity: isOfferEffectivelyAccepted && !isMine ? 0.7 : 1.0,
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Align(
              alignment: align,
              child: Container(
                margin: EdgeInsets.only(
                  left: isMine ? 60 : 12,
                  right: isMine ? 12 : 60,
                  top: 4,
                  bottom: 2,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: borderRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine)
                      CircleAvatar(
                        backgroundColor: avatarBackgroundColor,
                        foregroundColor: avatarForegroundColor,
                        backgroundImage: finalAvatarUrl.isNotEmpty
                            ? NetworkImage(finalAvatarUrl)
                            : null,
                        child: finalAvatarUrl.isEmpty
                            ? Text(displayChar)
                            : null,
                      ),
                    if (!isMine) const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMine)
                            Text(finalDisplayName,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: displayNameColor)),
                          if (!isMine) const SizedBox(height: 2),
                          Text(offer.message,
                              style: TextStyle(color: textColor, fontSize: 16)),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: isMine
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (offer.rate != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? rateBadgeBackgroundColorIsMine
                                        : rateBadgeBackgroundColorOther,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${offer.rate}%',
                                    style: TextStyle(
                                      color: isMine
                                          ? rateBadgeTextColorIsMine
                                          : rateBadgeTextColorOther,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (offer.rate != null) const SizedBox(width: 8),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('HH:mm').format(offer.createdAt),
                                    style: TextStyle(
                                      color: isMine
                                          ? timestampColorIsMine
                                          : timestampColorOther,
                                      fontSize: 12,
                                    ),
                                    textAlign:
                                        isMine ? TextAlign.right : TextAlign.left,
                                  ),
                                  if (isOfferEffectivelyAccepted)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: Icon(
                                        Icons.check_circle_outline,
                                        color: isMine ? timestampColorIsMine : Colors.green,
                                        size: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<Reply>>(
              stream: replyService.getRepliesStream(offer.id),
              builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData && !snapshot.hasError) {
                    return const SizedBox.shrink(); 
                }
                  
                  if (snapshot.hasError) {
                    print('OfferBubble: Error in replies stream for ${offer.id}: ${snapshot.error}');
                  return const SizedBox.shrink();
                }

                  final replies = snapshot.data ?? [];

                  if (replies.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                      return const SizedBox.shrink();
                  }
                  
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: replies
                      .map((reply) => ReplyBubble(
                            reply: reply,
                            offerType: offer.type,
                            isOfferOwner: isMine,
                            isOfferAccepted: isOfferEffectivelyAccepted,
                            onAcceptReply: isMine &&
                                      offer.status != 'accepted' &&
                                      reply.status == 'pending'
                                ? () {
                                    if (onAcceptOfferReply != null) {
                                      onAcceptOfferReply!(offer, reply);
                                    }
                                  }
                                : null,
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 