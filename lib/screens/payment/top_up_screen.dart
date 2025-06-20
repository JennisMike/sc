import 'package:flutter/material.dart';
import '../../services/payment_service.dart';

class TopUpScreen extends StatefulWidget {
  final double currentBalance;

  const TopUpScreen({
    super.key,
    required this.currentBalance,
  });

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _paymentService = PaymentService();
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _transactionStatus;

  @override
  void initState() {
    super.initState();
    _initializePaymentService();
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

  Future<void> _processTopUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _transactionStatus = null;
    });

    try {
      // Format phone number: remove spaces, +, and ensure it starts with 237
      String phone = _phoneController.text.trim();
      phone = phone.replaceAll(RegExp(r'[\s\+]'), ''); // Remove spaces and +
      if (!phone.startsWith('237')) {
        phone = '237$phone';
      }

      final result = await _paymentService.topUp(
        phone: phone,
        amount: _amountController.text.trim(),
        description: 'Top-up wallet',
      );

      setState(() {
        _transactionStatus = result;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Top-up request sent successfully!'),
            backgroundColor: Colors.green,
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
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Text('Top Up Wallet', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
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

              // Phone Number Input
              TextFormField(
                controller: _phoneController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number (e.g., 699999999)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  prefixText: '+237 ',
                  prefixStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  // Remove spaces and + for validation
                  final cleanNumber = value.replaceAll(RegExp(r'[\s\+]'), '');
                  if (cleanNumber.length < 9 || cleanNumber.length > 12) {
                    return 'Please enter a valid phone number (9-12 digits)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount Input
              TextFormField(
                controller: _amountController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Amount (XAF)',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.error, width: 1),
                  ),
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
                  if (amount > 100000) {
                    return 'Maximum top-up amount is XAF 100,000';
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
                        const Text(
                          'Transaction Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
                  onPressed: _isLoading ? null : _processTopUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary)
                      : const Text('Top Up'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 