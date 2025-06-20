import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'package:flutter/material.dart';
import 'transaction_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentService {
  static const String _appId = 'fdDqWQvd6rfeDgc06Iv9sVyZXucilAkDwnwaCEucEKvRcVk0a6DYmUvz-8yD5HyiDhBbJtnrcQCcAfg5gCEOGw';
  static const String _username = 'I_T8xtXFANYZ8CuhTxkpjHHPsCiz8ZCWShiHCW2HyAyD3L2NwKBR0TjTsJebKALD3RkaTaBbahLPr5D3knfA7g';
  static const String _password = 'SXaNZ02rO1cSEVTft3fDxHBDCKdAWjxXCMw9cLsr4D0f8ZejfrtTCu-pKGhZZ2STu05bwknl4LsJoc0N7-WudA';
  static const String _accessToken = '3c4a03643f96f2ad53875f5e6af7a098e1a8acb8';
  static const String _webhookKey = 'XZA0TG5C7OYSNfONUpQOIrN9J2oxqPkeifAHAYgk_hZWmkkZyrVmRHaeFc5s82oOP02LoF1W5gpMEfDK9BZy-w';

  final TransactionService _transactionService = TransactionService();
  late final SupabaseClient _supabase;
  String? _token;
  DateTime? _tokenExpiry;
  bool _isInitialized = false;

  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  Future<void> init() async {
    if (_isInitialized) return;
    _supabase = Supabase.instance.client;
    await _transactionService.init();
    _isInitialized = true;
  }

  Future<void> updateWalletBalance(double amount, {bool isTopUp = true}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user.id)
          .single();

      final currentBalance = (response['wallet_balance'] ?? 0.0).toDouble();
      final newBalance = isTopUp ? currentBalance + amount : currentBalance - amount;

      if (!isTopUp && newBalance < 0) {
        throw Exception('Insufficient balance');
      }

      await _supabase
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update wallet balance: $e');
    }
  }

  // Get authentication token
  Future<void> _getToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://demo.campay.net/api/token/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username,
          'password': _password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _tokenExpiry = DateTime.now().add(Duration(seconds: data['expires_in']));
        print('Campay token obtained: $_token');
        print('Campay token expires at: $_tokenExpiry');
      } else {
        throw Exception('Failed to get token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to get token: $e');
    }
  }

  // Ensure token is valid
  Future<void> _ensureValidToken() async {
    if (_token == null || _tokenExpiry == null || DateTime.now().isAfter(_tokenExpiry!)) {
      await _getToken();
    }
  }

  Future<Map<String, dynamic>> topUp({
    required String phone,
    required String amount,
    required String description,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Process top-up with CamPay
      final result = await _processPayment(
        phone: phone,
        amount: amount,
        description: description,
        isTopUp: true,
      );

      // Create transaction record
      await _transactionService.createTransaction(
        userId: user.id,
        type: 'topup',
        amount: double.parse(amount),
        description: description,
        reference: result['reference'],
        transactionId: result['transaction_id'],
      );

      return {
        ...result,
        'status': 'pending',
      };
    } catch (e) {
      throw Exception('Top-up failed: $e');
    }
  }

  Future<Map<String, dynamic>> withdraw({
    required String phone,
    required String amount,
    required String description,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user.id)
          .single();

      final currentBalance = (response['wallet_balance'] ?? 0.0).toDouble();
      final withdrawAmount = double.parse(amount);

      if (currentBalance < withdrawAmount) {
        throw Exception('Insufficient balance');
      }

      // Process withdrawal with CamPay
      final result = await _processPayment(
        phone: phone,
        amount: amount,
        description: description,
        isTopUp: false,
      );

      // Create transaction record
      await _transactionService.createTransaction(
        userId: user.id,
        type: 'withdraw',
        amount: withdrawAmount,
        description: description,
        reference: result['reference'],
        transactionId: result['transaction_id'],
      );

      return {
        ...result,
        'status': 'pending',
      };
    } catch (e) {
      throw Exception('Withdrawal failed: $e');
    }
  }

  Future<Map<String, dynamic>> _processPayment({
    required String phone,
    required String amount,
    required String description,
    required bool isTopUp,
  }) async {
    await _ensureValidToken();
    final reference = '${isTopUp ? "TOPUP" : "WITHDRAW"}_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
    
    try {
      print('Processing ${isTopUp ? "top-up" : "withdrawal"} payment:');
      print('Phone: $phone');
      print('Amount: $amount');
      print('Reference: $reference');
      
      final Map<String, String> body;
      String effectivePhone = phone; // Initialize with the original phone

      if (isTopUp) {
        String effectivePhoneForTopUp = phone;
        if (phone.startsWith('237') && phone.length == 12) {
          effectivePhoneForTopUp = phone.substring(3);
          print('Top-up: Extracted 9-digit number for Campay: $effectivePhoneForTopUp from $phone');
        } else {
          // If not a 12-digit 237-prefixed number, use as is. top_up_screen.dart should ensure 237xxxxxxxxx format.
          print('Top-up: Phone number ($phone) not a 12-digit 237-prefixed number. Using as is: $effectivePhoneForTopUp. This might be an issue if Campay strictly expects 9 digits after 237 stripping.');
        }
        body = {
          'phone_number': effectivePhoneForTopUp, // Use the processed phone number
          'amount': amount,
          'description': description,
          'external_reference': reference,
          // 'app_id': _appId, // Temporarily removed for testing if it resolves invalid phone number for top-ups
        };
        print('Top-up payload (app_id removed for test): $body');
      } else {
        // For withdrawals, use the phone number as is (expected to be 237xxxxxxxxx)
        print('Withdrawal: Using phone number for Campay: $effectivePhone');
        body = {
          'to': effectivePhone, // 'effectivePhone' is still the original 'phone' here
          'amount': amount,
          'description': description,
          'external_reference': reference,
          'app_id': _appId,
        };
      }

      print('Using Campay token for API request: $_token');
      final response = await http.post(
        Uri.parse('https://demo.campay.net/api/${isTopUp ? "collect" : "withdraw"}/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'status': 'successful',
          'reference': reference,
          'amount': amount,
          'phone': phone,
          'description': description,
          'transaction_id': data['id'],
        };
      } else {
        final errorBody = jsonDecode(response.body);
        String errorMessage;
        
        if (response.statusCode == 400) {
          errorMessage = 'Invalid request: ${errorBody['message'] ?? errorBody['detail'] ?? 'Please check your input values'}';
        } else if (response.statusCode == 401) {
          errorMessage = 'Authentication failed: Please try again or contact support';
        } else if (response.statusCode == 403) {
          errorMessage = 'Transaction not authorized: ${errorBody['message'] ?? 'Insufficient funds or unauthorized transaction'}';
        } else if (response.statusCode == 404) {
          errorMessage = 'Service not found: Please try again later';
        } else if (response.statusCode == 429) {
          errorMessage = 'Too many requests: Please wait a moment before trying again';
        } else if (response.statusCode >= 500) {
          errorMessage = 'Server error: Please try again later';
        } else {
          errorMessage = errorBody['message'] ?? errorBody['detail'] ?? response.body;
        }
        
        print('Payment error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Payment processing error: $e');
      if (e is FormatException) {
        throw Exception('Invalid response from server. Please try again.');
      } else if (e.toString().contains('SocketException')) {
        throw Exception('Network error: Please check your internet connection and try again.');
      } else if (e.toString().contains('401')) {
        throw Exception('Authentication failed: Your session may have expired. Please try again.');
      } else if (e.toString().contains('403')) {
        throw Exception('Transaction not authorized: Please check your balance and try again.');
      } else if (e.toString().contains('404')) {
        throw Exception('Service unavailable: Please try again later.');
      } else if (e.toString().contains('429')) {
        throw Exception('Too many requests: Please wait a moment before trying again.');
      } else if (e.toString().contains('500')) {
        throw Exception('Server error: Please try again later or contact support.');
      } else {
        throw Exception('Transaction failed: ${e.toString()}');
      }
    }
  }

  // Get transaction status
  Future<Map<String, dynamic>> getTransactionStatus(String reference) async {
    await _ensureValidToken();
    try {
      print('Checking transaction status for reference: $reference');
      
      final response = await http.get(
        Uri.parse('https://demo.campay.net/api/transaction/$reference/'),
        headers: {
          'Authorization': 'Token $_token',
          'Content-Type': 'application/json',
        },
      );
      
      print('Transaction status response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Update transaction status in our database
        if (data['id'] != null && data['status'] != null) {
          print('Updating transaction status: ${data['status']}');
          await _transactionService.updateTransactionStatus(data['id'], data['status']);
          
          // If transaction is successful, update wallet balance
          if (data['status'] == 'successful') {
            print('Transaction successful, updating wallet balance');
            final transaction = await _transactionService.getTransactionById(data['id']);
            if (transaction != null) {
              await updateWalletBalance(
                transaction.amount,
                isTopUp: transaction.type == 'topup',
              );
              print('Wallet balance updated successfully');
            } else {
              print('Warning: Transaction found but details not retrieved');
            }
          } else {
            print('Transaction status: ${data['status']}');
          }
        } else {
          print('Warning: Transaction data missing required fields');
        }
        return data;
      } else {
        final errorMessage = 'Failed to get transaction status: ${response.statusCode} - ${response.body}';
        print(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error checking transaction status: $e');
      throw Exception('Failed to get transaction status: $e');
    }
  }

  // Handle webhook updates
  Future<void> handleWebhookUpdate(Map<String, dynamic> webhookData) async {
    try {
      final transactionId = webhookData['transaction_id'];
      final status = webhookData['status'];
      
      if (transactionId != null && status != null) {
        // Update transaction status
        await _transactionService.updateTransactionStatus(transactionId, status);
        
        // If transaction is successful, update wallet balance
        if (status == 'successful') {
          final transaction = await _transactionService.getTransactionById(transactionId);
          if (transaction != null) {
            await updateWalletBalance(
              transaction.amount,
              isTopUp: transaction.type == 'topup',
            );
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to handle webhook update: $e');
    }
  }
} 