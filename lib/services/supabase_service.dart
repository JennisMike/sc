import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late final String supabaseUrl;
  late final String supabaseAnonKey;

  Future<void> initialize() async {
    try {
      // Load environment variables
      await dotenv.load(fileName: ".env");
      
      supabaseUrl = dotenv.get('SUPABASE_URL');
      supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY');
      
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception('Missing Supabase configuration in .env file');
      }
      
      print('Initializing Supabase...');
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('Supabase initialized successfully');
    } catch (e) {
      print('Error initializing Supabase: $e');
      rethrow;
    }
  }

  SupabaseClient get client => Supabase.instance.client;

  // Helper method to get offers
  Future<List<Map<String, dynamic>>> getOffers({
    String? status,
    String? userId,
    int? limit,
    int? offset,
  }) async {
    final query = client.from('offers').select();
    
    if (status != null) {
      query.eq('status', status);
    }
    if (userId != null) {
      query.eq('user_id', userId);
    }
    if (limit != null) {
      query.limit(limit);
    }
    if (offset != null) {
      query.range(offset, offset + (limit ?? 10) - 1);
    }

    return await query.order('created_at', ascending: false);
  }

  // Helper method to get replies
  Future<List<Map<String, dynamic>>> getReplies({
    required String offerId,
    String? status,
    bool? isPublic,
    int? limit,
    int? offset,
  }) async {
    final query = client.from('replies').select().eq('offer_id', offerId);
    
    if (status != null) {
      query.eq('status', status);
    }
    if (isPublic != null) {
      query.eq('is_public', isPublic);
    }
    if (limit != null) {
      query.limit(limit);
    }
    if (offset != null) {
      query.range(offset, offset + (limit ?? 10) - 1);
    }

    return await query.order('created_at', ascending: true);
  }

  // Helper method to get replies for a user's offers
  Future<List<Map<String, dynamic>>> getRepliesToUserOffers({
    required String userId,
    String? status,
    bool? isPublic,
    int? limit,
    int? offset,
  }) async {
    final query = client
        .from('replies')
        .select('*, offers!inner(*)')
        .eq('offers.user_id', userId);
    
    if (status != null) {
      query.eq('status', status);
    }
    if (isPublic != null) {
      query.eq('is_public', isPublic);
    }
    if (limit != null) {
      query.limit(limit);
    }
    if (offset != null) {
      query.range(offset, offset + (limit ?? 10) - 1);
    }

    return await query.order('created_at', ascending: false);
  }
} 