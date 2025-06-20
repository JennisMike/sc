import 'package:flutter/material.dart';

/// Helper functions for WhatsApp-like behavior in the marketplace screen
class MarketplaceHelper {
  /// Scrolls to the bottom of the list
  static void scrollToBottom(ScrollController scrollController) {
    if (!scrollController.hasClients) return;
    
    final position = scrollController.position.maxScrollExtent;
    scrollController.animateTo(
      position,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
  
  /// Checks if user is scrolling near the top to load more messages
  static bool shouldLoadMore(ScrollController scrollController) {
    if (!scrollController.hasClients) return false;
    
    // Load more when user scrolls to the top (like WhatsApp when scrolling up)
    return scrollController.position.pixels <= scrollController.position.minScrollExtent + 50;
  }
}
