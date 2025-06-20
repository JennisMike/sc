import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import '../models/transaction_model.dart'; // Assuming Transaction model is in transaction_model.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// Riverpod provider for TransactionService
final transactionServiceProvider = Provider<TransactionService>((ref) {
  final service = TransactionService();
  // service.init(); // Consider if init needs to be called here or if constructor handles it
  return service;
});

class TransactionService {
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  static const Duration _transactionTimeout = Duration(minutes: 4);
  final Map<String, DateTime> _pendingTransactions = {};
  late final SupabaseClient _supabase;

  Future<void> init() async {
    _supabase = Supabase.instance.client;
    _startTransactionTimeoutChecker();
  }

  void _startTransactionTimeoutChecker() {
    Future.delayed(const Duration(seconds: 15), () async {
      await _checkPendingTransactions();
      _startTransactionTimeoutChecker();
    });
  }

  Future<void> _checkPendingTransactions() async {
    final now = DateTime.now();
    final transactionsToUpdate = <String>[];

    _pendingTransactions.forEach((transactionId, startTime) {
      final duration = now.difference(startTime);
      print('Checking transaction $transactionId: ${duration.inMinutes}m ${duration.inSeconds % 60}s elapsed');
      if (duration > _transactionTimeout) {
        print('Transaction $transactionId exceeded timeout of ${_transactionTimeout.inMinutes} minutes');
        transactionsToUpdate.add(transactionId);
      }
    });

    for (final transactionId in transactionsToUpdate) {
      try {
        print('Updating transaction $transactionId to failed status');
        await updateTransactionStatus(transactionId, 'failed');
        _pendingTransactions.remove(transactionId);
        print('Successfully marked transaction $transactionId as failed');
      } catch (e) {
        print('Error updating transaction $transactionId status: $e');
      }
    }
  }

  Future<Transaction> createTransaction({
    required String userId,
    required String type,
    required double amount,
    required String description,
    String? reference,
    String? transactionId,
  }) async {
    try {
      final data = {
        'user_id': userId,
        'type': type,
        'amount': amount,
        'status': 'pending',
        'description': description,
        'reference': reference,
        'transaction_id': transactionId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('transactions')
          .insert(data)
          .select()
          .single();

      if (transactionId != null) {
        _pendingTransactions[transactionId] = DateTime.now();
      }

      return Transaction.fromMap(response);
    } catch (e) {
      throw Exception('Failed to create transaction: $e');
    }
  }

  Future<void> updateTransactionStatus(String transactionId, String status) async {
    try {
      print('Updating transaction status for ID: $transactionId to $status');
      
      await _supabase
          .from('transactions')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('transaction_id', transactionId);
          // .select().single() was removed as the updated record wasn't being used.
          // If the update fails on a non-existent ID or other error, Supabase throws an error.

      print('Transaction status update attempt successful for ID: $transactionId');
    } catch (e) {
      print('Error updating transaction status: $e');
      throw Exception('Failed to update transaction status: $e');
    }
  }

  Future<Transaction?> getTransactionById(String transactionId) async {
    try {
      print('Fetching transaction by ID: $transactionId');
      
      final response = await _supabase
          .from('transactions')
          .select()
          .eq('transaction_id', transactionId)
          .single();

      // If .single() did not throw, a record was found.
      // 'response' here is the record map.
      final transaction = Transaction.fromMap(response);
      print('Transaction found: ${transaction.id}');
      return transaction;
    } catch (e) {
      print('Error fetching transaction: $e');
      throw Exception('Failed to fetch transaction: $e');
    }
  }

  Stream<List<Transaction>> getRecentTransactions(String userId, {int limit = 10}) {
    try {
      return _supabase
          .from('transactions')
          .stream(primaryKey: ['id']) // Assuming 'id' is your primary key column
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit)
          .map((listOfMaps) {
        return listOfMaps.map((map) => Transaction.fromMap(map)).toList();
      });
    } catch (e) {
      print('Error streaming recent transactions: $e');
      return Stream.value([]); // Return an empty stream on error
    }
  }

  Stream<List<Transaction>> getAllTransactions(String userId) {
    try {
      return _supabase
          .from('transactions')
          .stream(primaryKey: ['id']) // Assuming 'id' is your primary key column
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((listOfMaps) {
        return listOfMaps.map((map) => Transaction.fromMap(map)).toList();
      });
    } catch (e) {
      print('Error streaming all transactions: $e');
      return Stream.value([]); // Return an empty stream on error
    }
  }

  Stream<List<Transaction>> getTopUpAndWithdrawalHistory() {
    String? userId;
    try {
      userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('User not authenticated, returning empty stream for transaction history.');
        return Stream.value([]);
      }
      print('Streaming top-up and withdrawal history for user: $userId');
      
      return _supabase
          .from('transactions')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId) // userId is already checked for null
          .map((listOfMaps) {
            // Client-side filtering for type and sorting
            var filteredList = listOfMaps
                .map((map) => Transaction.fromMap(map)) // Removed unnecessary cast
                .where((tx) => tx.type == 'topup' || tx.type == 'withdrawal')
                .toList();
            filteredList.sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Sort descending by date
            
            print('Transaction history stream update with ${filteredList.length} items for user $userId.');
            return filteredList;
          });
    } catch (e) {
      print('Error streaming transaction history for user ${userId ?? 'unknown'}: $e');
      return Stream.value([]); // Return an empty stream on error
    }
  }
} 