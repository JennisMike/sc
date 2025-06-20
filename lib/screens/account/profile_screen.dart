import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import '../../models/user_model.dart';
import '../payment/withdraw_screen.dart';
import '../payment/top_up_screen.dart';
import '../payment/transaction_history_screen.dart'; // Added for navigation
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/error_utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool showBalance = true;
  late final NumberFormat _numberFormat;
  
  // Helper getters to access profile data
  UserModel? get _userProfile => ref.watch(userProfileProvider);
  String get username => _userProfile?.username ?? '';
  String get email => _userProfile?.email ?? '';
  String get phone => _userProfile?.phoneNumber ?? '';
  String get avatarUrl => _userProfile?.profilePicture ?? '';
  double get walletBalance => ref.watch(walletBalanceProvider);
  bool get isDarkMode => ref.watch(themeModeProvider) == ThemeMode.dark;
  String? get currentUserId => _userProfile?.id;

  @override
  void initState() {
    super.initState();
    _numberFormat = NumberFormat('#,###');
    // Load user profile data after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  /// Load the user profile using Riverpod's profile repository
  Future<void> _loadUserProfile() async {
    try {
      // Access the profile repository and load the user profile
      await ref.read(profileRepositoryProvider.notifier).loadUserProfile();
    } catch (e) {
      if (mounted) {
        ErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  /// Toggle dark mode using the Riverpod state provider
  Future<void> _toggleDarkMode(bool value) async {
    try {
      // Update dark mode using the theme mode notifier
      await ref.read(themeModeProvider.notifier).toggleTheme(value);
    } catch (e) {
      if (mounted) {
        ErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _goToEditProfile() async {
    print('Edit profile tapped');
    if (_userProfile == null) {
      print('User profile is null');
      return;
    }
    
    print('Navigating to edit profile');
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(
            userProfile: _userProfile!,
          ),
        ),
      );

      print('Returned from edit profile with result: $result');
      if (result == true) {
        // Refresh profile data using Riverpod
        await _loadUserProfile();
      }
    } catch (e) {
      print('Error navigating to edit profile: $e');
      if (mounted) {
        ErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      // Use Riverpod auth repository for logout
      await ref.read(authRepositoryProvider.notifier).signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Profile Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 40) : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(username, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(phone, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _goToEditProfile,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 20, color: Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 2. Wallet Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: Icon(showBalance ? Icons.visibility : Icons.visibility_off),
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  showBalance = !showBalance;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            showBalance ? '₣${_numberFormat.format(walletBalance)}' : '₣****',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[50],
                                foregroundColor: Colors.green[800],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.arrow_downward),
                              label: const Text('Top Up'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TopUpScreen(
                                      currentBalance: walletBalance,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red[800],
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.arrow_upward),
                              label: const Text('Withdraw'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WithdrawScreen(
                                      currentBalance: walletBalance,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // 4. Link to Transaction History
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                    );
                  },
                  child: Text('View All Transactions', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              // 3. Account Settings Section
              Text('Account Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('Wallet Phone Number'),
                      subtitle: Text(phone),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _goToEditProfile,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.nightlight_round),
                      title: const Text('Dark Mode'),
                      trailing: Switch(
                        value: isDarkMode,
                        onChanged: _toggleDarkMode,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(email),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _goToEditProfile,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Password'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {}, // TODO: Change password
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // 4. Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _logout,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
