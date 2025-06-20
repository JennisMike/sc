import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/offer_model.dart';
// import '../services/supabase_offer_service.dart'; // Service is accessed via its own provider
import 'offer_service_provider.dart'; // Correct: Import the FutureProvider

// StreamProvider for offers
final offersStreamProvider = StreamProvider.autoDispose<List<Offer>>((ref) {
  print("Riverpod: offersStreamProvider invoked.");
  // Watch the FutureProvider. This will give an AsyncValue.
  final offerServiceAsyncValue = ref.watch(supabaseOfferServiceProvider);

  return offerServiceAsyncValue.when(
    data: (offerService) {
      print("Riverpod: offersStreamProvider - SupabaseOfferService successfully loaded. Accessing offersStream.");
      // The service is now guaranteed to be initialized.
      return offerService.offersStream;
    },
    loading: () {
      print("Riverpod: offersStreamProvider - SupabaseOfferService is loading (initializing). Yielding empty stream for now.");
      return Stream.value(<Offer>[]); // Explicitly type the empty list for the stream
    },
    error: (error, stackTrace) {
      print("Riverpod: offersStreamProvider - Error loading SupabaseOfferService: $error\n$stackTrace");
      return Stream.error(error, stackTrace);
    },
  );
});

// Provider for loading more offers (pagination)
final offerLoadMoreProvider = FutureProvider.autoDispose<bool>((ref) async {
  print("Riverpod: offerLoadMoreProvider invoked.");
  // Await the future from the FutureProvider to get the initialized service.
  final offerService = await ref.watch(supabaseOfferServiceProvider.future);
  print("Riverpod: offerLoadMoreProvider - SupabaseOfferService available. Calling loadMoreOffers().");
  return offerService.loadMoreOffers();
});

// Provider for refreshing offers
final refreshOffersProvider = FutureProvider.autoDispose<void>((ref) async {
  print("Riverpod: refreshOffersProvider invoked.");
  // Await the future from the FutureProvider to get the initialized service.
  final offerService = await ref.watch(supabaseOfferServiceProvider.future);
  print("Riverpod: refreshOffersProvider - SupabaseOfferService available. Calling refreshOffers().");
  return offerService.refreshOffers();
});

// If you need to add an offer and want the UI to react immediately
// without a full refresh, you could expose the service directly
// or create a dedicated StateNotifier that manages the list and
// listens to the stream, providing methods to add/update locally
// while also relying on the stream for external changes.
// For now, relying on the stream and refresh should be sufficient. 