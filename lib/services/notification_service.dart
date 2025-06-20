import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // If you use Riverpod for services
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';
import '../models/reply_model.dart';
import '../providers/profile_provider.dart'; // For localNotificationsPluginProvider

// Riverpod provider for AuthService (assuming it's defined elsewhere like this)
// If not, you'll need to provide AuthService instance directly or via another mechanism.
// Example: final authServiceProv// Riverpod provider for the NotificationService
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final flutterLocalNotificationsPlugin = ref.watch(localNotificationsPluginProvider);
  return NotificationService(authService, Supabase.instance.client, flutterLocalNotificationsPlugin);
});

class NotificationService {
  final AuthService _authService;
  final SupabaseClient _supabaseClient;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _repliesChannel;

  NotificationService(this._authService, this._supabaseClient, this._flutterLocalNotificationsPlugin) {
    _init();
  }

  void _init() {
    _authSubscription = _authService.onAuthStateChange.listen((AuthState authState) {
      final userId = authState.session?.user.id;
      if (authState.event == AuthChangeEvent.signedIn && userId != null) {
        print('[NotificationService] User signed in ($userId). Starting to listen for replies.');
        _listenForNewReplies(userId);
      } else if (authState.event == AuthChangeEvent.signedOut) {
        print('[NotificationService] User signed out. Stopping reply listener.');
        _unsubscribeFromReplies();
      }
    });

    final currentUserId = _authService.currentUser?.id;
    if (currentUserId != null) {
      print('[NotificationService] User already signed in ($currentUserId). Starting to listen for replies.');
      _listenForNewReplies(currentUserId);
    }
  }

  void _listenForNewReplies(String currentUserId) {
    _unsubscribeFromReplies(); 

    _repliesChannel = _supabaseClient
        .channel('public:replies:offer_owner_id=eq.$currentUserId') // Unique channel name per user
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'replies',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'offer_owner_id',
            value: currentUserId,
          ),
          callback: (PostgresChangePayload payload) async {
            print('[NotificationService] New reply payload: ${payload.eventType}, Data: ${payload.newRecord}');
            if (payload.eventType == PostgresChangeEvent.insert && payload.newRecord.isNotEmpty) {
              try {
                final newReply = Reply.fromMap(payload.newRecord);
                
                final offerData = await _supabaseClient
                    .from('offers')
                    .select('type, amount') // Select only needed fields
                    .eq('id', newReply.offerId)
                    .maybeSingle();

                String offerSummary = "your offer";
                if (offerData != null && offerData.isNotEmpty) {
                  // Offer.fromMap might not be needed if we only need type and amount
                  offerSummary = "your offer '${offerData['type'] ?? 'N/A'}' for ${offerData['amount'] ?? 'N/A'}";
                }

                const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
                  'swap_chat_notifications',
                  'Swap Chat Notifications',
                  channelDescription: 'Notifications for new replies and messages in Swap Chat',
                  importance: Importance.max,
                  priority: Priority.high,
                  showWhen: false,
                );
                const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

                await _flutterLocalNotificationsPlugin.show(
                  0, // Notification ID
                  'NEW REPLY: ${newReply.userDisplayName} replied to your offer!', // Title
                  'Offer: ${offerSummary}\nMessage: ${newReply.message}', // Body
                  platformChannelSpecifics,
                  payload: 'reply_notification_${newReply.id}', // Custom payload for handling taps
                );

              } catch (e, stackTrace) {
                print('[NotificationService] Error processing new reply payload: $e');
                print('[NotificationService] StackTrace: $stackTrace');
                print('[NotificationService] Erroneous Payload: ${payload.newRecord}');
              }
            } else {
               print('[NotificationService] Received payload with null or empty newRecord for reply.');
            }
          },
        )
        .subscribe(
          (status, [error]) async {
             print('[NotificationService] Replies channel (for user $currentUserId) status: $status, Error: $error');
            if (status == RealtimeSubscribeStatus.subscribed) {
              print('[NotificationService] Successfully subscribed to new replies for user $currentUserId.');
            } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
              print('[NotificationService] Error/Timeout subscribing to replies for $currentUserId: $error. Will attempt to resubscribe after delay.');
              await Future.delayed(const Duration(seconds: 10)); // Increased delay
              // Check if still the same user and if service is not disposed
              if (_authService.currentUser?.id == currentUserId && _repliesChannel != null) { 
                 print('[NotificationService] Retrying subscription for user $currentUserId...');
                 _listenForNewReplies(currentUserId);
              }
            } else if (status == RealtimeSubscribeStatus.closed) {
                print('[NotificationService] Replies channel for $currentUserId was closed.');
            }
          }
        );
  }

  void _unsubscribeFromReplies() {
    if (_repliesChannel != null) {
      final channelName = 'realtime:public:replies:offer_owner_id=eq.${_authService.currentUser?.id}'; // Reconstruct or infer
      print('[NotificationService] Unsubscribing from replies channel for user ${_authService.currentUser?.id}. Channel topic was: $channelName');
      _supabaseClient.removeChannel(_repliesChannel!); 
      _repliesChannel = null;
    }
  }

  void dispose() {
    print('[NotificationService] Disposing NotificationService.');
    _authSubscription?.cancel();
    _unsubscribeFromReplies();
  }
}
