// This file is now reserved for MarketplaceScreen or other marketplace-related widgets only. All navigation and tab logic is in main_navigation.dart.

import 'package:flutter/material.dart';
import 'marketplace_screen.dart';
import 'main_navigation.dart'; // For color constants, if needed

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MarketplaceScreen(),
    );
  }
}

