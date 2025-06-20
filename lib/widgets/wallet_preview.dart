import 'package:flutter/material.dart';
import '../screens/home/main_navigation.dart';

class WalletPreview extends StatelessWidget {
  const WalletPreview({super.key, required this.balance});
  final double balance;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kAccentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: kAccentColor, size: 20),
          const SizedBox(width: 6),
          Text(
            '${balance.toStringAsFixed(0)} FCFA',
            style: const TextStyle(color: kAccentColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
} 