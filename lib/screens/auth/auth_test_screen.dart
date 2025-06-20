import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../utils/logger.dart';
import '../../services/auth_service.dart';

/// Test screen to verify Riverpod-based authentication is working correctly
class AuthTestScreen extends ConsumerWidget {
  const AuthTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logger = AppLogger();
    final currentUserState = ref.watch(currentUserProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authentication Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusCard(
              title: 'Auth State',
              content: currentUserState.when(
                data: (user) => user != null ? 'Authenticated' : 'Not authenticated',
                loading: () => 'Loading...',
                error: (error, stack) => 'Error: $error',
              ),
              icon: Icons.security,
              color: currentUserState.maybeWhen(
                data: (user) => user != null ? Colors.green : Colors.orange,
                orElse: () => Colors.orange,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusCard(
              title: 'Authenticated',
              content: isAuthenticated ? 'Yes' : 'No',
              icon: isAuthenticated ? Icons.check_circle : Icons.cancel,
              color: isAuthenticated ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            _buildStatusCard(
              title: 'User Info',
              content: currentUserState.when(
                data: (user) => user != null
                  ? 'ID: ${user.id}\nEmail: ${user.email}\nBalance: ${user.walletBalance}'
                  : 'No user logged in',
                loading: () => 'Loading user data...',
                error: (err, stack) => 'Error: $err',
              ),
              icon: Icons.person,
              color: currentUserState.maybeWhen(
                data: (user) => user != null ? Colors.blue : Colors.grey,
                orElse: () => Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  final authService = AuthService();
                  await authService.logout();
                  logger.info('Signed out successfully');
                } catch (e) {
                  logger.error('Error signing out', e);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(content),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
