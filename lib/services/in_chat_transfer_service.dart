import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final inChatTransferServiceProvider = Provider<InChatTransferService>((ref) {
  final supabaseClient = Supabase.instance.client;
  return InChatTransferService(supabaseClient);
});

class InChatTransferService {
  final SupabaseClient _supabaseClient;

  InChatTransferService(this._supabaseClient);

  Future<Map<String, dynamic>> initiateTransfer({
    required String senderId,
    required String receiverId,
    required double amount,
    String? description,
    String? chatMessageId, // Optional: if you want to link it immediately
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Transfer amount must be positive.');
    }
    if (senderId == receiverId) {
      throw ArgumentError('Sender and receiver cannot be the same person.');
    }

    try {
      final response = await _supabaseClient.functions.invoke(
        'perform-transfer', // This is the name of your Edge Function
        body: {
          'senderId': senderId,
          'receiverId': receiverId,
          'amount': amount,
          if (description != null) 'description': description,
          if (chatMessageId != null) 'chatMessageId': chatMessageId,
        },
      );

      if (response.status != 200 || response.data == null) {
        // Attempt to parse error from response.data if available
        String errorMessage = 'Failed to perform transfer.';
        if (response.data != null && response.data['error'] != null) {
          errorMessage = response.data['error'].toString();
        } else {
          // response.status is guaranteed to be non-null if we reached here after response.status != 200
          errorMessage += ' Status: ${response.status}';
        }
        throw Exception(errorMessage);
      }
      
      // Assuming the Edge Function returns data in the format: { message: '...', transfer: { ... } }
      // or just { error: '...' } on failure (which is handled above)
      return response.data as Map<String, dynamic>;

    } catch (e) {
      print('Error calling perform-transfer Edge Function: $e');
      // Re-throw a more specific or user-friendly error if needed
      if (e is Exception && e.toString().contains('Insufficient balance')) {
        throw Exception('Insufficient balance.');
      }
      if (e is Exception && e.toString().contains('Sender not found or error') ){
         throw Exception('Sender account issue. Please try again or contact support.');
      }
       if (e is Exception && e.toString().contains('Receiver not found or error') ){
         throw Exception('Receiver account issue. Please ensure the recipient is valid.');
      }
      throw Exception('An unexpected error occurred during the transfer: ${e.toString()}');
    }
  }
}
