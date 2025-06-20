import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import 'package:intl/intl.dart'; // For date formatting
import '../../services/transaction_service.dart'; // Contains transactionServiceProvider
import '../../models/transaction_model.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  Stream<List<Transaction>>? _transactionsStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream directly using ref.read from the provider
    // No need for setState here as StreamBuilder will listen to _transactionsStream
    _transactionsStream = ref.read(transactionServiceProvider).getTopUpAndWithdrawalHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction History', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              IconData iconData;
              Color iconColor;
              String title;

              if (transaction.type == 'topup') {
                iconData = Icons.arrow_upward;
                iconColor = Colors.green;
                title = 'Top-up';
              } else if (transaction.type == 'withdrawal') {
                iconData = Icons.arrow_downward;
                iconColor = Colors.red;
                title = 'Withdrawal';
              } else {
                // Should not happen based on the service filter, but good to have a fallback
                iconData = Icons.swap_horiz;
                iconColor = Theme.of(context).colorScheme.onSurface;
                title = transaction.type.toString().split('.').last; // 'pending' -> 'Pending'
                title = title[0].toUpperCase() + title.substring(1);
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor.withOpacity(0.1),
                    child: Icon(iconData, color: iconColor, size: 24),
                  ),
                  title: Text(title, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    DateFormat('MMM dd, yyyy - hh:mm a').format(transaction.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'XAF ${transaction.amount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: transaction.status == 'failed' 
                                  ? Theme.of(context).colorScheme.error 
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      Text(
                        transaction.status.toString().split('.').last[0].toUpperCase() + 
                        transaction.status.toString().split('.').last.substring(1),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: transaction.status == 'pending'
                                  ? Colors.orange
                                  : transaction.status == 'failed'
                                      ? Theme.of(context).colorScheme.error
                                      : Colors.green, // Assuming 'successful' or similar for green
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
