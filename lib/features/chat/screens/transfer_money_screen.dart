import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/in_chat_transfer_service.dart'; // Import the new service
import '../providers/chat_providers.dart'; // Import chatServiceProvider

class TransferMoneyScreen extends ConsumerStatefulWidget {
  final String recipientId;
  final String recipientDisplayName;
  final String? recipientAvatarUrl;
  final String conversationId; // Added conversationId

  const TransferMoneyScreen({
    super.key,
    required this.recipientId,
    required this.recipientDisplayName,
    this.recipientAvatarUrl,
    required this.conversationId, // Added conversationId
  });

  @override
  ConsumerState<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends ConsumerState<TransferMoneyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isProcessingTransfer = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _performTransfer() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid positive amount.')),
        );
        return;
      }

      final currentUser = ref.read(authRepositoryProvider).value?.user;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Could not identify current user. Please try again.')),
        );
        return;
      }
      final currentBalance = currentUser.walletBalance; 

      if (amount > currentBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance to perform this transfer.')),
        );
        return;
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Transfer'),
          content: Text('Transfer ${amount.toStringAsFixed(2)} FCFA to ${widget.recipientDisplayName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        setState(() {
          _isProcessingTransfer = true;
        });
        try {
          final transferService = ref.read(inChatTransferServiceProvider);
          final result = await transferService.initiateTransfer(
            senderId: currentUser.id,
            receiverId: widget.recipientId,
            amount: amount,
            description: 'Chat transfer to ${widget.recipientDisplayName}',
          );

          // ***** DEBUG PRINT 1: Raw Edge Function Result *****
          print('--- TransferMoneyScreen: initiateTransfer result ---\n$result');
          // ****************************************************

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'Transfer successful!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
          // TODO: Optionally, send a chat message here to notify about the transfer
          // Send a chat notification for the transfer
          try {
            final chatService = ref.read(chatServiceProvider);
            // Extract details from the Edge Function's response (result)
            final Map<String, dynamic> transferDataFromResult = result['data'] as Map<String, dynamic>? ?? {};

            // ***** DEBUG PRINT 2: Extracted data from result['data'] *****
            print('--- TransferMoneyScreen: transferDataFromResult (from result[\'data\']) ---');
            print('Amount: ${transferDataFromResult['amount']}');
            print('Currency: ${transferDataFromResult['currency']}');
            print('Sender Name: ${transferDataFromResult['sender_name']}');
            print('Receiver Name: ${transferDataFromResult['receiver_name']}');
            print('Full data: $transferDataFromResult');
            // ****************************************************************
            
            final num amountFromTextField = amount; // 'amount' is double.tryParse(_amountController.text) ?? 0.0;

            // ***** DETAILED DEBUG FOR AMOUNT *****
            print('--- TransferMoneyScreen: Amount Derivation ---');
            print('Raw result[data][amount]: ${transferDataFromResult['amount']} (Type: ${transferDataFromResult['amount']?.runtimeType})');
            print('Amount from TextField: $amountFromTextField');
            final num finalAmount;
            if (transferDataFromResult['amount'] != null && transferDataFromResult['amount'] is num && (transferDataFromResult['amount'] as num) != 0) {
                finalAmount = transferDataFromResult['amount'] as num;
                print('Using amount from Edge Function result (non-zero): $finalAmount');
            } else {
                finalAmount = amountFromTextField;
                if (transferDataFromResult['amount'] == null) {
                  print('Amount from Edge Function result is null. Using amount from TextField: $finalAmount');
                } else if (transferDataFromResult['amount'] is! num) {
                  print('Amount from Edge Function result is not num (Type: ${transferDataFromResult['amount']?.runtimeType}). Using amount from TextField: $finalAmount');
                } else { // Amount was 0 from Edge function
                  print('Amount from Edge Function result is 0. Using amount from TextField: $finalAmount');
                }
            }
            // *************************************

            final String finalCurrency = (transferDataFromResult['currency'] as String?) ?? 'FCFA';
            final String? senderNameFromResult = transferDataFromResult['sender_name'] as String?;

            // ***** DETAILED DEBUG FOR RECEIVER NAME *****
            print('--- TransferMoneyScreen: Receiver Name Derivation ---');
            print('Raw result[data][receiver_name]: ${transferDataFromResult['receiver_name']} (Type: ${transferDataFromResult['receiver_name']?.runtimeType})');
            print('widget.recipientDisplayName: ${widget.recipientDisplayName}');
            final String? finalReceiverName;
            if (transferDataFromResult['receiver_name'] != null && transferDataFromResult['receiver_name'] is String && (transferDataFromResult['receiver_name'] as String).isNotEmpty) {
                finalReceiverName = transferDataFromResult['receiver_name'] as String;
                print('Using receiver_name from Edge Function result: $finalReceiverName');
            } else {
                finalReceiverName = widget.recipientDisplayName;
                 if (transferDataFromResult['receiver_name'] == null) {
                  print('receiver_name from Edge Function result is null. Using widget.recipientDisplayName: $finalReceiverName');
                } else if (transferDataFromResult['receiver_name'] is! String) {
                  print('receiver_name from Edge Function result is not String (Type: ${transferDataFromResult['receiver_name']?.runtimeType}). Using widget.recipientDisplayName: $finalReceiverName');
                } else { // Is string but empty
                  print('receiver_name from Edge Function result is an empty string. Using widget.recipientDisplayName: $finalReceiverName');
                }
            }
            // ******************************************

            final String? finalSenderName = senderNameFromResult ?? currentUser.username ?? currentUser.id;

            final Map<String, dynamic> constructedMetadata = {
              'amount': finalAmount, // finalAmount already prioritizes result['data']['amount']
              'currency': finalCurrency,
              'sender_name': finalSenderName ?? currentUser.username ?? currentUser.id, // Prioritize result['data']['sender_name']
              'receiver_name': finalReceiverName, // Prioritize result['data']['receiver_name'], finalReceiverName already includes this fallback
            };

            // ***** DEBUG PRINT 3: Final constructed metadata for chat message *****
            print('--- TransferMoneyScreen: final constructedMetadata ---');
            print('Final Amount: ${constructedMetadata['amount']}');
            print('Final Currency: ${constructedMetadata['currency']}');
            print('Final Sender Name: ${constructedMetadata['sender_name']}');
            print('Final Receiver Name: ${constructedMetadata['receiver_name']}');
            print('Full metadata: $constructedMetadata');
            // *********************************************************************

            await chatService.sendTransferNotificationMessage(
              conversationId: widget.conversationId,
              senderId: currentUser.id,
              transferMetadata: constructedMetadata,
              senderDisplayName: currentUser.username, 
              senderAvatarUrl: currentUser.profilePicture, 
            );
          } catch (e) {
            print('Error sending transfer notification chat message: $e');
            // Optionally show a non-critical error to the user, but don't block popping the screen
          }

          // Pop the screen after successful transfer
          if (mounted) Navigator.of(context).pop();

        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transfer failed: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        } finally {
          if (mounted) {
            setState(() {
              _isProcessingTransfer = false;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserModel = ref.watch(authRepositoryProvider).value?.user;
    final currentBalance = currentUserModel?.walletBalance ?? 0.0;

    final String displayChar = widget.recipientDisplayName.isNotEmpty 
        ? widget.recipientDisplayName[0].toUpperCase() 
        : '?';

    return Scaffold(
      appBar: AppBar(
        title: Text('Transfer to ${widget.recipientDisplayName}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: widget.recipientAvatarUrl != null && widget.recipientAvatarUrl!.isNotEmpty
                        ? NetworkImage(widget.recipientAvatarUrl!)
                        : null,
                    child: widget.recipientAvatarUrl == null || widget.recipientAvatarUrl!.isEmpty
                        ? Text(displayChar, style: const TextStyle(fontSize: 24))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(widget.recipientDisplayName, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 24),
              Text('Your current balance: ${currentBalance.toStringAsFixed(2)} FCFA', 
                   style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (FCFA)',
                  border: OutlineInputBorder(),
                  prefixText: 'FCFA ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid positive amount';
                  }
                  final currentUser = ref.read(authRepositoryProvider).value?.user;
                  final currentBalance = currentUser?.walletBalance ?? 0.0;
                  if (amount > currentBalance) {
                    return 'Insufficient balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: _isProcessingTransfer ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Proceed to Transfer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: Theme.of(context).textTheme.titleMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _isProcessingTransfer ? null : _performTransfer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
