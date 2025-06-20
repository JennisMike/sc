import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../services/transaction_service.dart';

class TransactionHistoryWidget extends StatefulWidget {
  final String userId;
  final bool showAll;

  const TransactionHistoryWidget({
    Key? key,
    required this.userId,
    this.showAll = false,
  }) : super(key: key);

  @override
  State<TransactionHistoryWidget> createState() => _TransactionHistoryWidgetState();
}

class _TransactionHistoryWidgetState extends State<TransactionHistoryWidget> {
  final TransactionService _transactionService = TransactionService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Stream<List<Transaction>> transactionStream;
      if (widget.showAll) {
        transactionStream = _transactionService.getAllTransactions(widget.userId);
      } else {
        transactionStream = _transactionService.getRecentTransactions(widget.userId);
      }

      final transactions = await transactionStream.first;

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load transactions: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_transactions.isEmpty) {
      return const Center(
        child: Text('No transactions found'),
      );
    }

    return Container(
      height: 200, // Fixed height for the list
      child: ListView.builder(
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionItem(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final isTopUp = transaction.type == 'topup';
    final amount = transaction.amount;
    final formattedAmount = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isTopUp ? Colors.green : Colors.orange,
          child: Icon(
            isTopUp ? Icons.add : Icons.remove,
            color: Colors.white,
          ),
        ),
        title: Text(
          isTopUp ? 'Top Up' : 'Withdrawal',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.description),
            Text(
              DateFormat('MMM dd, yyyy HH:mm').format(transaction.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isTopUp ? '+' : '-'}$formattedAmount',
              style: TextStyle(
                color: isTopUp ? Colors.green : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              transaction.status.toUpperCase(),
              style: TextStyle(
                color: _getStatusColor(transaction.status),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'successful':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
} 