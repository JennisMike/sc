import 'package:flutter/material.dart';
import 'marketplace_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import 'exchange_screen.dart';
import '../account/profile_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/exchange_rate_provider.dart';
import '../../services/auth_service.dart';

const Color kPrimaryColor = Color(0xFF1D3557);
const Color kAccentColor = Color(0xFF2A9D8F);
const Color kBackgroundColor = Color(0xFFF8FAFC);
const Color kTextColor = Color(0xFF2D2D2D);
const Color kErrorColor = Color(0xFFE63946);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  double walletBalance = 50000.0;
  final AuthService _authService = AuthService();
  String? currentUserId;

  final GlobalKey _marketplaceKey = GlobalKey();
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _initializeServicesAndUser();
    _pages = [
      MarketplaceScreen(key: _marketplaceKey),
      const ChatListScreen(),
      const ExchangeScreen(),
      const ProfileScreen(),
    ];
  }

  Future<void> _initializeServicesAndUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        currentUserId = user.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
                _selectedIndex == 0
                    ? 'Marketplace'
                    : _selectedIndex == 1
                        ? 'Chats'
                        : _selectedIndex == 2
                            ? 'Exchange'
                            : 'Account',
                style: theme.appBarTheme.titleTextStyle,
              ),
        centerTitle: false,
        actions: [
          if (_selectedIndex == 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Center(
                child: Consumer(
                  builder: (context, ref, child) {
                    final exchangeRateAsyncValue = ref.watch(exchangeRateProvider);
                    return exchangeRateAsyncValue.when(
                      data: (exchangeRateData) {
                        if (exchangeRateData != null) {
                          final rateFormatted = exchangeRateData.rate.toStringAsFixed(4);
                          // Using full currency names for clarity
                          final base = exchangeRateData.baseCurrency.isNotEmpty ? exchangeRateData.baseCurrency : '?';
                          final target = exchangeRateData.targetCurrency.isNotEmpty ? exchangeRateData.targetCurrency : '?';
                          return Text(
                            '1 $base = $rateFormatted $target',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w500),
                          );
                        } else {
                          return Text(
                            'Rate N/A',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(0.7), fontWeight: FontWeight.w500),
                          );
                        }
                      },
                      loading: () => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary))),
                          const SizedBox(width: 8),
                          Text('Rate...', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary)),
                        ],
                      ),
                      error: (error, stackTrace) {
                        return Tooltip(
                          message: 'Rate Error',
                          child: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.errorContainer, size: 18), // Using errorContainer for better visibility on primary bg
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                // TODO: Implement notifications
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications will be implemented soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
        iconTheme: theme.iconTheme,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        // Styles are now controlled by BottomNavigationBarTheme in AppTheme
        // selectedItemColor: theme.bottomNavigationBarTheme.selectedItemColor,
        // unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
        // backgroundColor: theme.bottomNavigationBarTheme.backgroundColor,
        type: theme.bottomNavigationBarTheme.type ?? BottomNavigationBarType.fixed,
        elevation: theme.bottomNavigationBarTheme.elevation ?? 8,
        // selectedLabelStyle: theme.bottomNavigationBarTheme.selectedLabelStyle,
        // unselectedLabelStyle: theme.bottomNavigationBarTheme.unselectedLabelStyle,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Marketplace',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Exchange',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Account',
          ),
        ],
      ),
    );
  }
} 