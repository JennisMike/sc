import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../models/reply_model.dart';
import 'supabase_service.dart';

class SupabaseReplyService {
  // Make the singleton pattern safer for navigation
  static SupabaseReplyService? _instance;
  factory SupabaseReplyService() {
    if (_instance == null || _instance!._disposed) {
      _instance = SupabaseReplyService._internal();
    }
    return _instance!;
  }
  
  SupabaseReplyService._internal() {
    _initialize();
  }
  
  bool _disposed = false;
  bool _initialized = false;

  static const String _tableName = 'replies';

  // BehaviorSubject to stream replies for each offer
  final Map<String, BehaviorSubject<List<Reply>>> _replySubjects = {};

  // Keep track of offers for which replies have been fetched or are fetching
  // final Map<String, bool> _fetchStatus = {}; // Removed for simplification

  // Get stream for a specific offer's replies
  Stream<List<Reply>> getRepliesStream(String offerId) {
    _replySubjects[offerId] ??= BehaviorSubject<List<Reply>>.seeded([]);
    
    print("ReplyService: getRepliesStream called for offerId: $offerId");

    // Always attempt to fetch if not currently loading (fetchReplies will handle its own isLoading equivalent)
    // This simplifies the logic and ensures we try to get data if the stream is subscribed to.
    fetchReplies(offerId);
    
    return _replySubjects[offerId]!.stream;
  }

  void _initialize() {
    if (!_initialized) {
      _replySubjects.clear();
      _initialized = true;
      _disposed = false;

      _listenForReplyChanges(); // New method for real-time replies

      print('SupabaseReplyService initialized. Attempting to listen for reply changes.');
    }
  }
  
  RealtimeChannel? _repliesChannel;

  void _handleReplyRealtimePayload(PostgresChangePayload payload) {
    if (_disposed) return;

    print('[ReplyService Realtime] Event: ${payload.eventType}, Table: ${payload.table}');
    final eventType = payload.eventType;
    Map<String, dynamic> record;
    String? offerId;
    String? replyId;
    // No need for listNeedsUpdate variable as we're triggering fresh fetches

    try {
      if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update || eventType == PostgresChangeEvent.delete) {
        // For any change event, get the offerId from the record
        if (eventType == PostgresChangeEvent.insert || eventType == PostgresChangeEvent.update) {
          record = Map<String, dynamic>.from(payload.newRecord);
        } else { // delete event
          record = Map<String, dynamic>.from(payload.oldRecord);
        }
        
        offerId = record['offer_id']?.toString();
        replyId = record['id']?.toString();
        print('  [${eventType.toString().split('.').last}] Reply ID: $replyId for Offer ID: $offerId');
        
        // Instead of updating cache, just refresh data from Supabase
        if (offerId != null) {
          fetchReplies(offerId);
          print('    Triggered fresh fetch of replies for offer $offerId due to real-time event');
        }
      }
      
      // No need to do anything else here, as we've triggered a fresh fetch
    } catch (e, stack) {
      print('[ReplyService Realtime] Error processing payload for reply ID $replyId on offer $offerId: $e\n$stack');
    }
  }

  void _listenForReplyChanges() {
    if (_disposed) {
      print("[ReplyService Realtime] Attempted to listen while disposed.");
      return;
    }
    final client = SupabaseService().client;
    if (client == null) {
      print("[ReplyService Realtime] Supabase client is null. Cannot listen.");
      return;
    }

    _repliesChannel?.unsubscribe();
    _repliesChannel = null;
    print("[ReplyService Realtime] Previous channel unsubscribed if existed.");

    _repliesChannel = client
        .channel('public_replies_realtime') // Unique channel name
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tableName,
          callback: _handleReplyRealtimePayload,
        )
        .subscribe(
          (status, [error]) async {
            print("[ReplyService Realtime] Subscription Status: $status");
             if (_disposed && status != RealtimeSubscribeStatus.closed) {
                print("[ReplyService Realtime] Disposed during subscription, attempting to unsubscribe.");
                _repliesChannel?.unsubscribe();
                return;
            }
            if (status == RealtimeSubscribeStatus.subscribed) {
              print("[ReplyService Realtime] Successfully SUBSCRIBED. Replies will update in real-time.");
              // For replies, individual streams are typically fetched on demand by the UI.
              // A global refresh here might be too aggressive. The real-time events
              // should update any currently active reply streams.
              // Consider fetching for all *active* reply streams if needed:
              // for (var offerId in _replySubjects.keys) {
              //   if (_replySubjects[offerId]!.hasListener) {
              //     print("[ReplyService Realtime] Refreshing already active stream for offer $offerId post-subscription.");
              //     fetchReplies(offerId); 
              //   }
              // }
            } else if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
              print("[ReplyService Realtime] Subscription Error/Timeout: $error. Will attempt to resubscribe after delay.");
              // Consider a retry mechanism for reply channel as well
              await Future.delayed(const Duration(seconds: 5));
              if (!_disposed) {
                  print("[ReplyService Realtime] Retrying subscription...");
                  _listenForReplyChanges();
              }
            } else if (status == RealtimeSubscribeStatus.closed) {
                print("[ReplyService Realtime] Channel subscription explicitly closed.");
            }
          },
        );
  }

  Future<void> init() async {
    if (_disposed) _initialize(); // Re-initialize if disposed
    if (!_initialized) _initialize();
  }

  // Add a simple flag to prevent concurrent fetches for the *same* offerId
  final Set<String> _currentlyFetching = {};

  Future<void> fetchReplies(String offerId) async {
    if (_disposed || !_initialized) {
        print('ReplyService: FetchReplies for $offerId skipped: Service disposed ($_disposed) or not initialized ($_initialized).');
        return;
    }

    if (_currentlyFetching.contains(offerId)) {
      print('ReplyService: Already fetching replies for $offerId. Skipping duplicate call.');
      return;
    }
    
    print('ReplyService: Fetching replies for offer: $offerId');
    _currentlyFetching.add(offerId);
    
    try {
      final response = await SupabaseService().client
          .from(_tableName)
          .select()
          .eq('offer_id', offerId)
          // No status filter here, fetch all replies for the offer
          .order('created_at', ascending: true);

      final List<Reply> fetchedReplies = (response as List)
          .map((data) => Reply.fromMap(Map<String, dynamic>.from(data)))
          .toList();

      print('ReplyService: Fetched ${fetchedReplies.length} replies for offer $offerId.');

      // No caching, directly update the stream
      _replySubjects[offerId] ??= BehaviorSubject<List<Reply>>.seeded([]); // Ensure subject exists
      
      if (!_disposed && _replySubjects[offerId] != null && !_replySubjects[offerId]!.isClosed) {
        _replySubjects[offerId]!.add(List.unmodifiable(fetchedReplies)); // Update stream with fresh data (even if empty)
        print('ReplyService: Updated _replySubjects for $offerId with ${fetchedReplies.length} replies.');
      } else {
        print('ReplyService: Not updating _replySubjects for $offerId. Disposed: $_disposed, SubjectNull: ${_replySubjects[offerId] == null}, SubjectClosed: ${_replySubjects[offerId]?.isClosed}');
      }
    } catch (e) {
      print('ReplyService: Error fetching replies from Supabase for $offerId: $e');
      if (_replySubjects.containsKey(offerId) && !_replySubjects[offerId]!.isClosed) {
         _replySubjects[offerId]?.addError(e); 
      }
    } finally {
       _currentlyFetching.remove(offerId);
       print('ReplyService: Finished fetching cycle for $offerId.');
    }
  }

  Future<Reply> createReply({
    required String offerId,
    required String userId,
    required String userDisplayName,
    required String userAvatarUrl,
    required String message,
    required double rate,
    required double? amount,
    required bool isPublic,
    required String transactionSummaryForReplier,
    required String offerOwnerId,
  }) async {
    // Check if service is in valid state
    if (_disposed || !_initialized) {
      print('[SupabaseReplyService] createReply: Service is disposed ($_disposed) or not initialized ($_initialized). Skipping.');
      throw StateError('Cannot create reply: Service is disposed or not initialized');
    }
    
    print('[SupabaseReplyService] createReply: Attempting to create reply for OfferID: $offerId. UserID: $userId, Message: "$message"');

    // Outer try-catch for the whole operation, including client check
    try {
      print('[SupabaseReplyService] createReply: Preparing replyData...');
      final Map<String, dynamic> replyData = {
        'offer_id': offerId,
        'offer_owner_id': offerOwnerId,
        'user_id': userId,
        'user_display_name': userDisplayName,
        'user_avatar_url': userAvatarUrl,
        'message': message,
        'rate': rate,
        'amount': amount,
        'is_public': isPublic,
        'status': 'pending', // Default status
        'transaction_summary_for_replier': transactionSummaryForReplier,
      };
      print('[SupabaseReplyService] createReply: Prepared replyData: $replyData');

      final client = SupabaseService().client;
      if (client == null) {
        print('[SupabaseReplyService] createReply: Supabase client is NULL. Cannot proceed.');
        throw Exception('Supabase client is null'); // This will be caught by the outer try-catch
      }
      print('[SupabaseReplyService] createReply: Supabase client obtained. Proceeding with insert.');

      // Inner try-catch specifically for the database operation
      try {
        final response = await client
            .from(_tableName)
            .insert(replyData)
            .select()
            .single();

        print('[SupabaseReplyService] createReply: Insert successful. Response: $response');
        final newReply = Reply.fromMap(Map<String, dynamic>.from(response));
        print('[SupabaseReplyService] createReply: Mapped response to Reply model: $newReply');

        // After successful creation, trigger a fetch for this offer's replies
        // This will update any listeners, including the UI.
        fetchReplies(offerId);
        print('[SupabaseReplyService] createReply: Triggered fetchReplies for offer $offerId');

        return newReply;
      } catch (e, stack) { // Catch for Supabase insert/select/map errors
        print('[SupabaseReplyService] createReply: ERROR during Supabase operation (insert/select/map): $e');
        print('[SupabaseReplyService] createReply: Stacktrace: $stack');
        throw Exception('Failed to process reply with Supabase: $e'); // Re-throw to be caught by outer or propagate
      }
    } catch (e, stack) { // Outer catch for general errors (e.g., client null, or re-thrown from inner)
      print('[SupabaseReplyService] createReply: Overall ERROR in createReply: $e');
      print('[SupabaseReplyService] createReply: Overall Stacktrace: $stack');
      throw Exception('Failed to create reply (see logs for details): $e');
    }
  }

  Future<void> updateReplyStatus(String replyId, String newStatus) async {
    // Temporarily disabled updateReplyStatus
    /*
    // Check if service is in valid state
    if (_disposed || !_initialized) {
      print('SupabaseReplyService: updateReplyStatus SKIPPED for replyId: $replyId. Service disposed ($_disposed) or not initialized ($_initialized).');
      throw StateError('Cannot update reply: Service is disposed or not initialized');
    }

    print('SupabaseReplyService: Attempting to update replyId: $replyId to status: $newStatus');
    
    try {
      final nowUtc = DateTime.now().toUtc();
      final data = {
        'status': newStatus,
        'updated_at': nowUtc.toIso8601String(),
      };
      
      print('SupabaseReplyService: Update data prepared for replyId: $replyId: $data');

      // First, we need to get the current reply to find its offer_id (for stream updates)
      final currentReplyResponse = await SupabaseService().client
          .from(_tableName)
          .select()
          .eq('id', replyId)
          .single();
      
      final currentReply = Reply.fromMap(Map<String, dynamic>.from(currentReplyResponse));
      final offerId = currentReply.offerId;
      
      // Now update the reply
      final response = await SupabaseService().client
          .from(_tableName)
          .update(data)
          .eq('id', replyId);
      
      print('SupabaseReplyService: Supabase update response for replyId: $replyId: $response');

      // Always fetch fresh data from Supabase after updating a reply
      await fetchReplies(offerId);
      print('SupabaseReplyService: Triggered refresh of replies for offer $offerId after updating reply $replyId');
      
    } catch (e) {
      print('SupabaseReplyService: Error updating reply status in Supabase for replyId $replyId (status: $newStatus): $e');
      throw Exception('Failed to update reply status: $e');
    }
    */
    print('SupabaseReplyService: updateReplyStatus for replyId $replyId to $newStatus is temporarily disabled.');
    // Optionally, throw an exception or return a specific result to indicate it's disabled.
  }

  // Method to force refresh replies for an offer
  Future<void> refreshReplies(String offerId) async {
    if (_disposed || !_initialized) return;
    // Just fetch fresh data - no cache to clear anymore
    await fetchReplies(offerId);
    print('SupabaseReplyService: Manual refresh triggered for offer $offerId');
  }

  // Helper for checking service state
  bool get isActive => !_disposed && _initialized;
  
  Future<void> dispose() async {
    if (!_disposed) {
      print('Disposing SupabaseReplyService');
      _disposed = true;
      
      // Unsubscribe from real-time events
      if (_repliesChannel != null) {
        try {
          await SupabaseService().client.removeChannel(_repliesChannel!);
          _repliesChannel = null;
          print('SupabaseReplyService: Realtime subscription removed');
        } catch (e) {
          print('SupabaseReplyService: Error removing realtime subscription: $e');
        }
      }
      
      // Close all active streams
      for (var subject in _replySubjects.values) {
        if (!subject.isClosed) {
          await subject.close();
        }
      }
      
      // Clear caches
      _replySubjects.clear();
      
      _initialized = false;
      print('SupabaseReplyService: Disposal completed. _disposed=$_disposed, _initialized=$_initialized');
    }
  }
  
  // For debugging
  @override
  String toString() {
    return 'SupabaseReplyService(initialized: $_initialized, disposed: $_disposed)';
  }
} 