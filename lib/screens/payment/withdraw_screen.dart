import 'package:flutter/material.dart';
import '../../services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawScreen extends StatefulWidget {
  final double currentBalance;

  const WithdrawScreen({
    super.key,
    required this.currentBalance,
  });

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _paymentService = PaymentService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _transactionStatus;
  String? _userPhoneNumber;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
    _loadUserPhoneNumber();
  }

  Future<void> _loadUserPhoneNumber() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('phone')
            .eq('id', user.id)
            .single();
        setState(() {
          _userPhoneNumber = response['phone']?.toString();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load user phone number: $e';
      });
    }
  }

  Future<void> _initializePaymentService() async {
    try {
      await _paymentService.init();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize payment service: $e';
      });
    }
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_userPhoneNumber == null || _userPhoneNumber!.isEmpty) {
      setState(() {
        _errorMessage = 'Please add a phone number to your profile before withdrawing';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _transactionStatus = null;
    });

    try {
      // Format phone number: remove spaces, +, and ensure it starts with 237
      String phone = _userPhoneNumber!.trim();
      phone = phone.replaceAll(RegExp(r'[\s\+]'), ''); // Remove spaces and +
      if (!phone.startsWith('237')) {
        phone = '237$phone';
      }

      final result = await _paymentService.withdraw(
        phone: phone,
        amount: _amountController.text.trim(),
        description: 'Withdraw from wallet',
      );

      setState(() {
        _transactionStatus = result;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Withdrawal request sent successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Withdraw Funds', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Balance
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Balance',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'XAF ${widget.currentBalance.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Phone Number Display
              if (_userPhoneNumber != null && _userPhoneNumber!.isNotEmpty)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Withdrawal Phone Number',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _userPhoneNumber != null ? '+237 $_userPhoneNumber' : 'Phone number not available',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface, 
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 2,
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Phone Number Set',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please add a phone number to your profile before withdrawing funds.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            // Navigate to profile edit screen
                            Navigator.pushNamed(context, '/edit-profile');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: Text('Add Phone Number'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Amount Input
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Amount (XAF)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)
                  ),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.outline)
                  ),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                  ),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1)
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  if (amount > widget.currentBalance) {
                    return 'Insufficient balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),

              if (_transactionStatus != null)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status: ${_transactionStatus!['status']}',
                          style: TextStyle(
                            color: _transactionStatus!['status'] == 'successful'
                                ? Colors.green // Consider Theme.of(context).colorScheme.tertiary or a custom success color from theme
                                : _transactionStatus!['status'] == 'failed'
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.onSurface, // Or onSurfaceVariant
                          ),
                        ),
                        if (_transactionStatus!['reference'] != null)
                          Text('Reference: ${_transactionStatus!['reference']}'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Process Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_userPhoneNumber == null || _userPhoneNumber!.isEmpty) ? null : (_isLoading ? null : _processWithdrawal),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Consistent with TopUpScreen
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                      : Text('Withdraw'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 