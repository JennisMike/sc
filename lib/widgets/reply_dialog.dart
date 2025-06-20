import 'dart:async'; // For FutureOr
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/offer_model.dart';

class ReplyDialog extends StatefulWidget {
  final Offer offer;
  final FutureOr<void> Function(String message, double rate, double? amount, bool isPublic, String transactionSummary) onSendReply;

  const ReplyDialog({super.key, required this.offer, required this.onSendReply});

  @override
  State<ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<ReplyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _rateController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isPublic = true;

  // Exchange rate - TODO: Fetch from a reliable source
  final double _exchangeRateRmbToFcfa = 80.0;

  String _calculatedDisplayAmount = '';
  String _transactionSummaryForReplier = '';

  @override
  void initState() {
    super.initState();
    _rateController.addListener(_calculateAmounts);
    _amountController.addListener(_calculateAmounts);
    _calculateAmounts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _rateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _calculateAmounts() {
    setState(() {
      _calculatedDisplayAmount = '';
      _transactionSummaryForReplier = '';
      final offerRate = widget.offer.rate;

      if (widget.offer.type == 'Need RMB') {
        final replierProposedRate = double.tryParse(_rateController.text) ?? 0;
        if (replierProposedRate > 0 && replierProposedRate <= 20) {
          final discountedFcfa = widget.offer.amount * (1 - replierProposedRate / 100);
          final rmbAmountToPay = discountedFcfa / _exchangeRateRmbToFcfa;
          _calculatedDisplayAmount = 'You will pay ${NumberFormat('#,##0.00').format(rmbAmountToPay)} RMB to get ${NumberFormat('#,##0').format(widget.offer.amount)} FCFA';
          _transactionSummaryForReplier = 'To get ${NumberFormat('#,##0').format(widget.offer.amount)} FCFA, you pay ${NumberFormat('#,##0.00').format(rmbAmountToPay)} RMB (Rate: $replierProposedRate% vs Offer: No direct rate).';
        } else if (replierProposedRate > 20) {
          _calculatedDisplayAmount = 'Max rate is 20%';
        } else {
          _calculatedDisplayAmount = 'Enter a valid rate (1-20%)';
        }
      } else if (widget.offer.type == 'Need FCFA') {
        final replierProposedRate = double.tryParse(_rateController.text) ?? 0;
        if (replierProposedRate > 0 && replierProposedRate <= 20) {
          final discountedRmb = widget.offer.amount * (1 - replierProposedRate / 100);
          final fcfaAmountToPay = discountedRmb * _exchangeRateRmbToFcfa;
          _calculatedDisplayAmount = 'You will pay ${NumberFormat('#,##0').format(fcfaAmountToPay)} FCFA to get ${NumberFormat('#,##0.00').format(widget.offer.amount)} RMB';
          _transactionSummaryForReplier = 'To get ${NumberFormat('#,##0.00').format(widget.offer.amount)} RMB, you pay ${NumberFormat('#,##0').format(fcfaAmountToPay)} FCFA (Rate: $replierProposedRate% vs Offer: No direct rate).';
        } else if (replierProposedRate > 20) {
          _calculatedDisplayAmount = 'Max rate is 20%';
        } else {
           _calculatedDisplayAmount = 'Enter a valid rate (1-20%)';
        }
      } else if (widget.offer.type == 'RMB available') {
        final fcfaAmountFromReplier = double.tryParse(_amountController.text) ?? 0;
        if (fcfaAmountFromReplier > 0 && offerRate != null && offerRate > 0) {
          final rmbAmountToReceive = fcfaAmountFromReplier / _exchangeRateRmbToFcfa * (1 - offerRate / 100);
          _calculatedDisplayAmount = 'You will receive ${NumberFormat('#,##0.00').format(rmbAmountToReceive)} RMB for your ${NumberFormat('#,##0').format(fcfaAmountFromReplier)} FCFA';
          _transactionSummaryForReplier = 'For your ${NumberFormat('#,##0').format(fcfaAmountFromReplier)} FCFA, you receive ${NumberFormat('#,##0.00').format(rmbAmountToReceive)} RMB (Offer Rate: $offerRate%).';
        } else if (offerRate == null || offerRate <= 0) {
            _calculatedDisplayAmount = 'Offer has an invalid rate.';
        } else {
            _calculatedDisplayAmount = 'Enter FCFA amount you want to exchange.';
        }
      }
    });
  }

  void _sendReply() {
    if (_formKey.currentState!.validate()) {
      final message = _messageController.text;
      final rate = double.tryParse(_rateController.text) ?? (widget.offer.rate ?? 0);
      final amount = widget.offer.type == 'RMB available' 
          ? (double.tryParse(_amountController.text) ?? 0)
          : widget.offer.amount;
      
      _calculateAmounts();
      
      widget.onSendReply(message, rate, amount, _isPublic, _transactionSummaryForReplier.isNotEmpty ? _transactionSummaryForReplier : "No transaction summary generated.");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reply to ${widget.offer.userDisplayName}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.offer.message, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(labelText: 'Your Reply Message (Optional)'),
                maxLines: 3,
                minLines: 1,
              ),
              const SizedBox(height: 16),
              if (widget.offer.type == 'Need RMB' || widget.offer.type == 'Need FCFA')
                TextFormField(
                  controller: _rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Your Proposed Rate (%)', hintText: 'e.g., 5 for 5%'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter a rate';
                    final parsedRate = double.tryParse(value);
                    if (parsedRate == null || parsedRate <= 0) return 'Enter a valid rate > 0';
                    if (parsedRate > 20) return 'Max rate is 20%';
                    return null;
                  },
                ),
              if (widget.offer.type == 'RMB available')
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'FCFA Amount you want to exchange'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter an amount';
                    final parsedAmount = double.tryParse(value);
                    if (parsedAmount == null || parsedAmount <= 0) return 'Enter a valid amount > 0';
                    return null;
                  },
                ),
              const SizedBox(height: 8),
              if (_calculatedDisplayAmount.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(_calculatedDisplayAmount, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              Row(
                children: [
                  Checkbox(
                    value: _isPublic,
                    onChanged: (value) => setState(() => _isPublic = value!),
                  ),
                  const Text('Public Reply'),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _sendReply, child: const Text('Send Reply')),
      ],
    );
  }
} 