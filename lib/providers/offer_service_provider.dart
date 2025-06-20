import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_offer_service.dart';

// Provider for SupabaseOfferService instance
// This FutureProvider will ensure the service is initialized before being provided.
final supabaseOfferServiceProvider = FutureProvider<SupabaseOfferService>((ref) async {
  print("Riverpod: supabaseOfferServiceProvider (FutureProvider) invoked.");
  final service = SupabaseOfferService(); // Get instance via factory
  print("Riverpod: supabaseOfferServiceProvider - Instance obtained. Calling init() on service: ${service.hashCode}");
  await service.init(); // Ensure initialization is complete
  print("Riverpod: supabaseOfferServiceProvider - Service init() completed. Returning initialized service: ${service.hashCode}");
  return service;
}); 