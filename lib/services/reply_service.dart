import '../models/reply_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReplyService {
  final _supabase = Supabase.instance.client;

  ReplyService();

  Future<void> init() async {
    // No initialization needed without Hive
  }

  // Create a new reply
  Future<Reply> createReply({
    required String offerId,
    required String offerOwnerId,
    required String userId,
    required String userDisplayName,
    required String userAvatarUrl,
    required double rate,
    double? amount,
    bool isPublic = true,
    String message = '',
  }) async {
    try {
      final data = {
        'offer_id': offerId,
        'offer_owner_id': offerOwnerId,
        'user_id': userId,
        'user_display_name': userDisplayName,
        'user_avatar_url': userAvatarUrl,
        'rate': rate,
        'amount': amount,
        'is_public': isPublic,
        'status': 'pending',
        'message': message,
        'created_at': DateTime.now().toIso8601String(),
      };
      final response = await _supabase
          .from('replies')
          .insert(data)
          .select()
          .single();
      return Reply.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create reply: $e');
    }
  }

  // Stream of public replies for an offer
  Stream<List<Reply>> getPublicReplies(String offerId) async* {
    try {
      while (true) {
        try {
          final response = await _supabase
              .from('replies')
              .select()
              .eq('offer_id', offerId)
              .eq('is_public', true)
              .order('created_at', ascending: false);
          final replies = (response as List)
              .map((obj) => Reply.fromMap(obj))
              .toList();
          yield replies;
        } catch (e) {
          print('Error fetching public replies: $e');
          continue;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Failed to get public replies: $e');
      yield [];
    }
  }

  // Stream of all replies for an offer (for offer owner)
  Stream<List<Reply>> getAllRepliesForOffer(String offerId) async* {
    try {
      while (true) {
        try {
          final response = await _supabase
              .from('replies')
              .select()
              .eq('offer_id', offerId)
              .order('created_at', ascending: false);
          final replies = (response as List)
              .map((obj) => Reply.fromMap(obj))
              .toList();
          yield replies;
        } catch (e) {
          print('Error fetching all replies: $e');
          continue;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      print('Failed to get all replies for offer: $e');
      yield [];
    }
  }

  // Stream of replies to user's offers
  Stream<List<Reply>> getRepliesToMyOffers(String userId, {int limit = 10}) async* {
    try {
      while (true) {
        try {
          final response = await _supabase
              .from('replies')
              .select()
              .eq('offer_owner_id', userId)
              .order('created_at', ascending: false)
              .limit(limit);
          final replies = (response as List)
              .map((obj) => Reply.fromMap(obj))
              .toList();
          yield replies;
        } catch (e) {
          print('Error fetching replies to my offers: $e');
          yield [];
        }
        await Future.delayed(const Duration(seconds: 5));
      }
    } catch (e) {
      throw Exception('Failed to get replies to my offers: $e');
    }
  }

  // Update reply status
  Future<void> updateReplyStatus(String replyId, String status) async {
    try {
      await _supabase
          .from('replies')
          .update({'status': status})
          .eq('id', replyId)
          .select()
          .single();
    } catch (e) {
      throw Exception('Failed to update reply status: $e');
    }
  }
} 