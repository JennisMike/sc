import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reply_model.dart';
import '../models/offer_model.dart';

class ReplyNotificationPanel extends StatefulWidget {
  final List<Reply> repliesToMyOffers;
  final Map<String, Offer> offerDetailsCache;
  final Function(String offerId) onNotificationTap;
  final VoidCallback? onDismissAll;

  ReplyNotificationPanel({
    super.key,
    required this.repliesToMyOffers,
    required this.offerDetailsCache,
    required this.onNotificationTap,
    this.onDismissAll,
  });

  @override
  State<ReplyNotificationPanel> createState() => _ReplyNotificationPanelState();
}

class _ReplyNotificationPanelState extends State<ReplyNotificationPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.repliesToMyOffers.isEmpty) {
      return const SizedBox.shrink();
    }
    final showReplies = _expanded
        ? widget.repliesToMyOffers
        : widget.repliesToMyOffers.take(2).toList();
    final hasMore = widget.repliesToMyOffers.length > 2;

    return Container(
      padding: const EdgeInsets.all(8.0),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                child: Text(
                  'Recent Replies to Your Offers',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              if (hasMore)
                IconButton(
                  icon: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  tooltip: _expanded ? 'Show less' : 'Show more',
                ),
            ],
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxHeight: 150,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: showReplies.length,
              itemBuilder: (context, index) {
                final reply = showReplies[index];
                String offerSnippet = widget.offerDetailsCache[reply.offerId]?.message ?? 'one of your offers';
                if (offerSnippet.length > 30) {
                  offerSnippet = '${offerSnippet.substring(0, 27)}...';
                }
                return InkWell(
                  onTap: () => widget.onNotificationTap(reply.offerId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: reply.userAvatarUrl.isNotEmpty
                              ? NetworkImage(reply.userAvatarUrl)
                              : null,
                          child: reply.userAvatarUrl.isEmpty
                              ? Text(reply.userDisplayName.isNotEmpty ? reply.userDisplayName[0] : 'U', style: const TextStyle(fontSize: 10))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${reply.userDisplayName} ',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer),
                                ),
                                TextSpan(
                                  text: 'replied to "$offerSnippet"',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8)),
                                ),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('HH:mm').format(reply.createdAt),
                          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.onDismissAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onDismissAll,
                child: const Text('Dismiss All', style: TextStyle(fontSize: 12)),
              ),
            )
        ],
      ),
    );
  }
} 