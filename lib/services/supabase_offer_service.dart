import 'package:rxdart/rxdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/offer_model.dart';
import 'supabase_service.dart';

class SupabaseOfferService {
  // Make the singleton pattern safer for navigation
  static SupabaseOfferService? _instance;
  factory SupabaseOfferService() {
    if (_instance == null || _instance!._disposed) {
      print("SupabaseOfferService Factory: Creating new instance.");
      _instance = SupabaseOfferService._internal();
    } else {
      print("SupabaseOfferService Factory: Returning existing instance (initialized: ${_instance!._initialized}, disposed: ${_instance!._disposed}).");
    }
    return _instance!;
  }
  
  SupabaseOfferService._internal() {
    _offersSubject = BehaviorSubject<List<Offer>>.seeded([]);
    print("SupabaseOfferService._internal() CONSTRUCTOR EXECUTED. Service instance created, ready for init(). Flags: initialized=$_initialized, disposed=$_disposed");
  }

  bool _disposed = false;
  bool _initialized = false;
  RealtimeChannel? _offersChannel; // Keep a reference to the channel

  static const String _tableName = 'offers';
  
  // Pagination variables
  int _currentPage = 0;
  static const int _pageSize = 15; // Increased to 15 offers per page
  bool _hasMoreOffers = true;
  bool _isLoadingMore = false;

  // BehaviorSubject to stream the list of offers and notify listeners of changes
  late BehaviorSubject<List<Offer>> _offersSubject;

  // Public stream for the UI to listen to - offers are sorted with newest at bottom (like WhatsApp)
  Stream<List<Offer>> get offersStream => _offersSubject.stream;
  
  void _initialize() {
    print("SupabaseOfferService: ===== _initialize() CALLED ===== Flags: initialized=$_initialized, disposed=$_disposed");
    if (_initialized && !_disposed) {
        print('OfferService: _initialize() called but already initialized and not disposed. Skipping.');
        return;
    }
    if (_disposed) {
        print('OfferService: _initialize() called on disposed service. Skipping.');
        return;
    }
    print('OfferService: Starting _initialize() CORE LOGIC. Setting up streams and listeners.');

    _currentPage = 0;
    _hasMoreOffers = true;
    _isLoadingMore = false;
    
    _listenForOfferChanges(); 

      _initialized = true;
    // _disposed should be false here, set by factory or constructor logic.
    print('SupabaseOfferService _initialize() completed. Realtime listener setup initiated.');
  }

    // Rewritten to remove direct cache manipulation and trigger refresh
  Future<void> _handleOfferRealtimePayload(PostgresChangePayload payload) async {
    if (_disposed) {
      print('[OfferService Realtime] _handleOfferRealtimePayload called while disposed. Skipping.');
      return;
    }

    print('[OfferService Realtime] Event Received: ${payload.eventType}, Table: ${payload.table}');
    final eventType = payload.eventType;

    // For any relevant change, trigger a full refresh of the offers list from the database
    if (eventType == PostgresChangeEvent.insert ||
        eventType == PostgresChangeEvent.update ||
        eventType == PostgresChangeEvent.delete) {
      print('[OfferService Realtime] Relevant event received. Triggering refresh of offers.');
      // Add a small delay to allow DB transaction to complete before fetching, preventing race conditions
      await Future.delayed(const Duration(milliseconds: 500)); 
      await fetchAndLoadOffers(refresh: true); // Ensure this is awaited
    } else {
      print('[OfferService Realtime] Event ${payload.eventType} not triggering refresh.');
    }
  }

  void _listenForOfferChanges() {
    print("[OfferService Realtime] _listenForOfferChanges(): Entered method.");
    if (_disposed) {
      print("[OfferService Realtime] _listenForOfferChanges(): Attempted to listen while disposed.");
      return;
    }

    print("[OfferService Realtime] _listenForOfferChanges(): Accessing Supabase client...");
    final client = SupabaseService().client;
    if (client == null) {
      print("[OfferService Realtime] _listenForOfferChanges(): Supabase client is NULL. Cannot listen. Ensure Supabase is initialized before calling OfferService.init().");
      return;
    }
    print("[OfferService Realtime] _listenForOfferChanges(): Supabase client obtained successfully.");
    
    // Clean up existing channel before creating a new one
    if (_offersChannel != null) {
        print("[OfferService Realtime] Removing existing offers channel before creating a new one.");
        client.removeChannel(_offersChannel!); 
        _offersChannel = null;
    }
    
    print("[OfferService Realtime] Creating new channel 'public_offers_realtime' and subscribing...");
    _offersChannel = client
        .channel('public_offers_realtime') 
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _tableName, 
          callback: _handleOfferRealtimePayload,
        );
        
    _offersChannel!.subscribe(
      (status, [error]) async {
        print("[OfferService Realtime] Subscription Status Changed: $status");
        if (_disposed && status != RealtimeSubscribeStatus.closed) {
            print("[OfferService Realtime] Service disposed during a subscription status change (not closed). Unsubscribing channel.");
            await _offersChannel?.unsubscribe(); // Ensure unsubscribe is awaited
            _offersChannel = null; // Nullify after unsubscribe attempt
            return;
        }

        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            print("[OfferService Realtime] Successfully SUBSCRIBED to 'public_offers_realtime'. Performing initial data sync.");
            await fetchAndLoadOffers(refresh: true);
            break;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
            print("[OfferService Realtime] Subscription Error/Timeout: $error. Will attempt to resubscribe after delay.");
            if (!_disposed) {
              _offersSubject.addError(Exception('Realtime connection error: $status'));
              await _offersChannel?.unsubscribe(); // Unsubscribe before retrying
              _offersChannel = null;
              await Future.delayed(const Duration(seconds: 5)); 
              if (!_disposed) {
                  print("[OfferService Realtime] Retrying subscription due to error/timeout...");
                  _listenForOfferChanges(); 
              }
            }
            break;
          case RealtimeSubscribeStatus.closed:
            print("[OfferService Realtime] Channel 'public_offers_realtime' subscription explicitly closed.");
            // If not disposed, it might be an unexpected closure, consider resubscribing.
            if (!_disposed) {
                 print("[OfferService Realtime] Channel closed unexpectedly. Attempting to resubscribe after delay...");
                 await Future.delayed(const Duration(seconds: 5));
                 if(!_disposed) _listenForOfferChanges();
            }
            break;
        }
      },
    );
  }

  Future<void> init() async {
    print("SupabaseOfferService: ===== init() CALLED ===== Flags: initialized=$_initialized, disposed=$_disposed");
    if (_disposed) {
      print('OfferService: init() called on a disposed service. Skipping initialization.');
      return; 
    }

    if (!_initialized) {
      print('OfferService: init() - Not initialized. Calling _initialize().');
      _initialize(); 
      print('OfferService: init() - _initialize() call completed. Flags: initialized=$_initialized, disposed=$_disposed');
    } else {
      print('OfferService: init() called, but already initialized and not disposed. Skipping _initialize() call.');
    }
  }
  
  /// Load more offers when scrolling up (like WhatsApp)
  Future<bool> loadMoreOffers() async {
    if (_disposed || !_initialized || !_hasMoreOffers || _isLoadingMore) {
      return false;
    }
    
    _isLoadingMore = true;
    try {
      await fetchAndLoadOffers(refresh: false);
    return _hasMoreOffers;
    } finally {
      _isLoadingMore = false;
    }
  }
  
  /// Refresh offers (pull to refresh)
  Future<void> refreshOffers() async {
    if (_disposed || !_initialized) {
      return;
    }
    
    await fetchAndLoadOffers(refresh: true);
  }

  Future<void> fetchAndLoadOffers({bool refresh = false}) async {
    print("OfferService: fetchAndLoadOffers called. Refresh: $refresh, Disposed: $_disposed, Initialized: $_initialized");
    if (_disposed || !_initialized) {
      print('OfferService: fetchAndLoadOffers skipped: Service disposed or not initialized.');
      _offersSubject.addError(Exception("Service not ready"));
      return;
    }

    if (refresh) {
      print("OfferService: Refresh triggered. Resetting offers and pagination.");
      _currentPage = 0;
      _hasMoreOffers = true;
      // _offersSubject.add([]); // Clear immediately on refresh to show loading
    } else if (!_hasMoreOffers || _isLoadingMore) {
      print("OfferService: Not refreshing, and no more offers or already loading. CurrentPage: $_currentPage, HasMore: $_hasMoreOffers, IsLoading: $_isLoadingMore");
      return;
    }

    _isLoadingMore = true;
    print("OfferService: Fetching page $_currentPage (PageSize: $_pageSize)");

    try {
      final response = await SupabaseService().client
          .from(_tableName)
          .select('*') // Fetch all columns
          // .eq('status', 'active') // REMOVED: Fetch all offers regardless of status
          .order('created_at', ascending: false) // Keep newest at top for query
          .range(_currentPage * _pageSize, (_currentPage + 1) * _pageSize - 1);

      final List<Offer> fetchedOffers = (response as List)
          .map((data) {
            // Manually ensure 'replies' is an empty list if not present or not fetched
            final offerData = Map<String, dynamic>.from(data);
            if (offerData['replies'] == null) {
              offerData['replies'] = [];
            }
            return Offer.fromMap(offerData);
          })
          .toList();
      print('FetchOffers: Fetched ${fetchedOffers.length} offers for page $_currentPage.');

      if (fetchedOffers.length < _pageSize) {
        _hasMoreOffers = false;
        print('FetchOffers: No more offers after this page.');
      }
      
      // Get the current offers from the stream or an empty list if none
      List<Offer> currentOffers = [];
      if (!_disposed && _offersSubject.hasValue) {
        currentOffers = List<Offer>.from(_offersSubject.value);
      }
      
      // Update the list based on refresh or pagination
      List<Offer> updatedOffers;
      if (refresh) {
        // On refresh, replace the entire list
        updatedOffers = fetchedOffers;
      } else {
        // On pagination, add to existing offers ensuring no duplicates
        final existingIds = currentOffers.map((o) => o.id).toSet();
        updatedOffers = List<Offer>.from(currentOffers);
        for (final offer in fetchedOffers) {
          if (!existingIds.contains(offer.id)) {
            updatedOffers.add(offer);
          }
        }
      }
      
      // Sort oldest first for UI display
      updatedOffers.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _currentPage++;
      
      // Update the stream regardless of immediate listeners for initial load via BehaviorSubject
      if (!_disposed) {
        _offersSubject.add(List.unmodifiable(updatedOffers));
        print('FetchOffers: Updated offersSubject with ${updatedOffers.length} offers. Has listeners: ${_offersSubject.hasListener}');
      } else {
        print('FetchOffers: Service disposed after fetch. Not updating offersSubject.');
      }
    } catch (e, stackTrace) {
      print('FetchOffers: Error fetching offers: $e\n$stackTrace');
      if (!_disposed && _offersSubject.hasListener) {
        _offersSubject.addError(e);
      }
    } finally {
      _isLoadingMore = false;
      print('FetchOffers: Finished. Refresh: $refresh');
    }
  }

  Future<Offer> createOffer({
    required String userId,
    required String userDisplayName,
    required String userAvatarUrl,
    required String type,
    required double amount,
    double? rate,
    required String message,
  }) async {
    if (_disposed || !_initialized) {
      print('CreateOffer: Service is disposed ($_disposed) or not initialized ($_initialized). Skipping.');
      throw StateError('Cannot create offer: Service is disposed or not initialized');
    }
    
    print('CreateOffer: Attempting to create offer. UserID: $userId, Type: $type, Amount: $amount, Rate: $rate, Message: "$message"');
    try {
      final nowUtc = DateTime.now().toUtc();
      final data = {
        'user_id': userId,
        'user_display_name': userDisplayName,
        'user_avatar_url': userAvatarUrl,
        'type': type,
        'amount': amount,
        'rate': rate,
        'message': message,
        'status': 'active',
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      };
      print('CreateOffer: Data to insert: $data');

      final response = await SupabaseService().client
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      print('CreateOffer: Response from Supabase insert: $response');
      final newOffer = Offer.fromMap(Map<String, dynamic>.from(response));
      print('CreateOffer: Successfully created and parsed offer ID: ${newOffer.id}, CreatedAt: ${newOffer.createdAt.toLocal()}');

      // Instead of updating a local cache, refresh data from Supabase
      await fetchAndLoadOffers(refresh: true);
      print('CreateOffer: Triggered refresh of offers from Supabase after creation.');

      return newOffer;
    } catch (e, stackTrace) { 
      print('CreateOffer: Error creating offer in Supabase: $e\nStack trace:\n$stackTrace');
      throw Exception('Failed to create offer. Details: ${e.toString()}');
    }
  }

  Future<void> updateOfferStatus(
    String offerId, 
    String status, {
    String? acceptedByUserId,
    DateTime? acceptedAt,
  }) async {
    if (_disposed || !_initialized) {
      print('OfferService: updateOfferStatus skipped: Service disposed or not initialized.');
      return;
    }
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status == 'accepted') {
        if (acceptedByUserId != null) {
          updateData['accepted_by_user_id'] = acceptedByUserId;
        }
        if (acceptedAt != null) {
          updateData['accepted_at'] = acceptedAt.toIso8601String();
        } else {
          // If acceptedAt is not provided but status is accepted, default to now
          updateData['accepted_at'] = DateTime.now().toIso8601String(); 
        }
      } else {
        // If status is not 'accepted', explicitly nullify these fields
        // to handle cases where an offer might be, for example, cancelled after being accepted (if such a flow exists)
        updateData['accepted_by_user_id'] = null;
        updateData['accepted_at'] = null;
      }

      await SupabaseService().client
          .from(_tableName)
          .update(updateData)
          .eq('id', offerId);
      print('OfferService: Offer $offerId status updated to $status.');
      // Real-time listener _handleOfferRealtimePayload should trigger fetchAndLoadOffers(refresh: true)
    } catch (e) {
      print('OfferService: Error updating offer status for $offerId: $e');
      _offersSubject.addError(Exception('Error updating offer status: $e'));
      rethrow;
    }
  }

  // Modified to be a safe check without throwing errors
  bool get isActive => !_disposed && _initialized;

  Future<void> dispose() async {
    print('SupabaseOfferService: Disposing service...');
    _disposed = true;
    
    // Clean up subscription first to prevent any more events
    if (_offersChannel != null) {
      print('SupabaseOfferService: Removing realtime subscription...');
      try {
        final client = SupabaseService().client;
        await client.removeChannel(_offersChannel!);
        _offersChannel = null;
        print('SupabaseOfferService: Realtime subscription removed.');
      } catch (e) {
        print('SupabaseOfferService: Error removing realtime subscription: $e');
      }
    }
    
    // Close the stream controller
    if (!_offersSubject.isClosed) {
      print('SupabaseOfferService: Closing offersSubject...');
      await _offersSubject.close();
      print('SupabaseOfferService: offersSubject closed.');
    }
    
    _initialized = false;
    print('SupabaseOfferService: Disposal completed. _disposed=$_disposed, _initialized=$_initialized');
  }
  
  // For debugging
  @override
  String toString() {
    return 'SupabaseOfferService(initialized: $_initialized, disposed: $_disposed)';
  }
} 