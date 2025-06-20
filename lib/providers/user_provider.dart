import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider for the current authenticated user
final currentUserProvider = StateNotifierProvider<UserNotifier, AsyncValue<UserModel?>>((ref) {
  return UserNotifier();
});

/// Provider to check if the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userState = ref.watch(currentUserProvider);
  return userState.value != null;
});

/// Provider for the user's wallet balance
final walletBalanceProvider = Provider<double>((ref) {
  final userState = ref.watch(currentUserProvider);
  return userState.value?.walletBalance ?? 0.0;
});

/// Notifier for managing user state
class UserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final _authService = AuthService();
  final _supabase = Supabase.instance.client;
  
  UserNotifier() : super(const AsyncLoading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Set up auth change listener
      _setupAuthListener();
      
      // Check if user is already logged in
      final currentUser = _authService.currentUser;
      if (currentUser != null) {
        final profile = await _authService.getUserProfile(currentUser.id);
        if (profile != null) {
          state = AsyncData(UserModel.fromMap(profile));
        } else {
          state = const AsyncData(null);
        }
      } else {
        state = const AsyncData(null);
      }
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;
      
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        if (session != null) {
          try {
            final profile = await _authService.getUserProfile(session.user.id);
            if (profile != null) {
              state = AsyncData(UserModel.fromMap(profile));
            }
          } catch (e) {
            state = AsyncError(e, StackTrace.current);
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AsyncData(null);
      }
    });
  }
}
