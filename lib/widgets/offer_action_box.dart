import 'package:flutter/material.dart';

class OfferActionBox extends StatelessWidget {
  final bool isOwner;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback onClose;
  final String? offerStatus;

  const OfferActionBox({
    super.key,
    required this.isOwner,
    this.onDelete,
    this.onReply,
    required this.onClose,
    this.offerStatus,
  });

  @override
  Widget build(BuildContext context) {
    final bool canReplyToOffer = offerStatus != 'accepted';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner) ...[
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () {
                  onClose();
                  onDelete?.call();
                },
              ),
            ] else ...[
              _ActionButton(
                icon: Icons.reply,
                label: canReplyToOffer ? 'Reply' : 'Offer Accepted',
                color: canReplyToOffer ? Theme.of(context).primaryColor : Colors.grey,
                onTap: canReplyToOffer ? () {
                  onClose();
                  onReply?.call();
                } : () => onClose(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 