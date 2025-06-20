import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';
import '../models/transaction_model.dart';
import 'supabase_service.dart';

class SupabaseTransactionService {
  static final SupabaseTransactionService _instance = SupabaseTransactionService._internal();
  factory SupabaseTransactionService() => _instance;
  SupabaseTransactionService._internal();

  static const String _tableName = 'transactions';

  // Internal cache for transactions
  List<Transaction> _cachedTransactions = [];

  // BehaviorSubject to stream transactions
  final BehaviorSubject<List<Transaction>> _transactionsSubject = BehaviorSubject<List<Transaction>>.seeded([]);

  // Public stream for the UI to listen to
  Stream<List<Transaction>> get transactionsStream => _transactionsSubject.stream;

  Future<void> init() async {
    // No initialization needed without Hive
  }

  Future<void> fetchUserTransactions() async {
    try {
      final response = await SupabaseService().client
          .from(_tableName)
          .select()
          .or('sender_id.eq.${SupabaseService().client.auth.currentUser?.id},receiver_id.eq.${SupabaseService().client.auth.currentUser?.id}')
          .order('created_at', ascending: false);

      final List<Transaction> fetchedTransactions = (response as List)
          .map((data) => Transaction.fromMap(Map<String, dynamic>.from(data)))
          .toList();

      _cachedTransactions = fetchedTransactions;
      _transactionsSubject.add(List.unmodifiable(_cachedTransactions));

    } catch (e) {
      print('Error fetching transactions from Supabase: $e');
      _transactionsSubject.addError(e);
    }
  }

  Future<Transaction> createTransaction({
    required String offerId,
    required String senderId,
    required String receiverId,
    required double amount,
    String? paymentMethod,
    Map<String, dynamic>? paymentDetails,
  }) async {
    try {
      final data = {
        'offer_id': offerId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'amount': amount,
        'status': 'pending',
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (paymentDetails != null) 'payment_details': paymentDetails,
      };

      final response = await SupabaseService().client
          .from(_tableName)
          .insert(data)
          .select()
          .single();

      final newTransaction = Transaction.fromMap(Map<String, dynamic>.from(response));

      // Update cache and stream
      _cachedTransactions.insert(0, newTransaction);
      _transactionsSubject.add(List.unmodifiable(_cachedTransactions));

      return newTransaction;
    } catch (e) {
      print('Error creating transaction in Supabase: $e');
      throw Exception('Failed to create transaction: $e');
    }
  }

  Future<void> updateTransactionStatus(String transactionId, String newStatus) async {
    try {
      final data = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await SupabaseService().client
          .from(_tableName)
          .update(data)
          .eq('id', transactionId);

      // Update local cache
      final index = _cachedTransactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        final updatedTransaction = _cachedTransactions[index].copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
        );
        _cachedTransactions[index] = updatedTransaction;
        _transactionsSubject.add(List.unmodifiable(_cachedTransactions));
      }

    } catch (e) {
      print('Error updating transaction status in Supabase: $e');
      throw Exception('Failed to update transaction status: $e');
    }
  }

  void dispose() {
    _transactionsSubject.close();
  }
} 