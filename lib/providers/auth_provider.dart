import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../services/auth_service.dart';

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Authentication state for the app
enum AuthStatus { initial, authenticated, unauthenticated, error }

/// Authentication state class to handle auth data and status
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final Session? session;
  final AppError? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.session,
    this.error,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    Session? session,
    AppError? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      session: session ?? this.session,
      error: error ?? this.error,
    );
  }

  // Reset error state
  AuthState clearError() => copyWith(error: null);
}

/// Provider for the auth repository
final authRepositoryProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  return AuthNotifier();
});

/// Auth notifier class for state management
class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final _supabase = Supabase.instance.client;
  final _logger = AppLogger();
  final _errorHandler = ErrorHandler();
  
  AuthNotifier() : super(const AsyncLoading()) {
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      // Setup auth state change listener
      _setupAuthStateListener();

      // Initial state based on current session
      final session = _supabase.auth.currentSession;
      if (session != null) {
        try {
          final userProfile = await _getUserProfile(session.user.id);
          state = AsyncData(AuthState(
            status: AuthStatus.authenticated,
            user: userProfile,
            session: session,
          ));
        } catch (e, stack) {
          _logger.error('Error loading user profile', e, stack);
          state = AsyncData(AuthState(
            status: AuthStatus.error,
            error: _errorHandler.handleException(e, stack),
            session: session,
          ));
        }
      } else {
        state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
      }
    } catch (e, stack) {
      _logger.error('Error initializing auth state', e, stack);
      state = AsyncError(e, stack);
    }
  }

  void _setupAuthStateListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      _logger.debug('Auth state changed: $event, Session: ${session?.user.id}');

      switch (event) {
        case AuthChangeEvent.signedIn:
          if (session != null) {
            try {
              final user = await _getUserProfile(session.user.id);
              state = AsyncData(AuthState(
                status: AuthStatus.authenticated,
                user: user,
                session: session,
              ));
            } catch (e, stack) {
              _logger.error('Error during sign in state update', e, stack);
              state = AsyncData(AuthState(
                status: AuthStatus.error,
                error: _errorHandler.handleException(e, stack),
                session: session,
              ));
            }
          }
          break;

        case AuthChangeEvent.signedOut:
        case AuthChangeEvent.userDeleted:
          state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
          break;

        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          if (session != null) {
            try {
              final user = await _getUserProfile(session.user.id);
              state = AsyncData(AuthState(
                status: AuthStatus.authenticated,
                user: user,
                session: session,
              ));
            } catch (e, stack) {
              _logger.error('Error during token refresh', e, stack);
            }
          }
          break;

        default:
          break;
      }
    });
  }

  Future<UserModel> _getUserProfile(String userId) async {
    try {
      try {
        // Try to get the existing profile
        final response = await _supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .single();

        return UserModel.fromMap(response);
      } catch (e) {
        _logger.warning('Profile not found for user $userId, creating one');
        
        // Get user email from auth data
        final user = _supabase.auth.currentUser;
        if (user == null) {
          throw Exception('Cannot create profile: No authenticated user');
        }
        
        // Create a default profile - only using fields that exist in the table
        final defaultProfile = {
          'id': userId,
          'email': user.email ?? '',
          'username': user.email?.split('@').first ?? 'user_$userId',
          // 'display_name' field doesn't exist in the table, so we're not including it
          'wallet_balance': 0.0,
          // Only include these if they exist in your table schema
          // 'created_at': DateTime.now().toIso8601String(),
          // 'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Insert the profile
        await _supabase.from('profiles').insert(defaultProfile);
        _logger.info('Created new profile for user $userId');
        
        // Return the newly created profile
        return UserModel.fromMap(defaultProfile);
      }
    } catch (e, stack) {
      _logger.error('Error handling user profile', e, stack);
      throw e;
    }
  }

  // Sign in with email and password
  Future<void> signInWithEmail(String email, String password) async {
    try {
      state = const AsyncLoading();

      _logger.info('Signing in with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );

      _logger.info('Sign in successful: ${response.user?.id}');
      
      // Session initialization is handled by the auth state listener
    } catch (e, stack) {
      _logger.error('Sign in failed', e, stack);
      state = AsyncData(AuthState(
        status: AuthStatus.error,
        error: _errorHandler.handleException(e, stack),
      ));
      rethrow;
    }
  }

  // Sign up with email and password
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      state = const AsyncLoading();

      _logger.info('Signing up with email: $email');
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'username': email.trim(),
          'display_name': email.trim().split('@').first,
        },
      );

      _logger.info('Sign up successful: ${response.user?.id}');

      // Insert profile into the database if user was created
      if (response.user != null) {
        try {
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email.trim(),
            'username': email.trim(),
            'wallet_balance': 0.0,
          });
          _logger.info('Profile created successfully');

          // Explicitly sign in to ensure session is immediately available
          if (_supabase.auth.currentSession == null) {
            _logger.warning('No session detected after signup, explicitly signing in...');
            final signInResponse = await _supabase.auth.signInWithPassword(
              email: email.trim(),
              password: password.trim(),
            );
            _logger.info('Explicit sign in completed: ${signInResponse.user?.id}');
            
            // Manually update state to ensure immediate UI update
            if (signInResponse.user != null) {
              final userProfile = await _getUserProfile(signInResponse.user!.id);
              state = AsyncData(AuthState(
                status: AuthStatus.authenticated,
                user: userProfile,
                session: signInResponse.session,
              ));
            }
          } else {
            // If session already exists, still update state manually
            final currentUser = _supabase.auth.currentUser;
            if (currentUser != null) {
              final userProfile = await _getUserProfile(currentUser.id);
              state = AsyncData(AuthState(
                status: AuthStatus.authenticated,
                user: userProfile,
                session: _supabase.auth.currentSession,
              ));
            }
          }
          
        } catch (e, stack) {
          _logger.error('Error creating profile', e, stack);
          throw e;
        }
      }
    } catch (e, stack) {
      _logger.error('Sign up failed', e, stack);
      state = AsyncData(AuthState(
        status: AuthStatus.error,
        error: _errorHandler.handleException(e, stack),
      ));
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      state = const AsyncLoading();
      await _supabase.auth.signOut();
      _logger.info('User signed out successfully');
      
      // Session change is handled by the auth state listener
    } catch (e, stack) {
      _logger.error('Sign out failed', e, stack);
      state = AsyncData(AuthState(
        status: AuthStatus.error,
        error: _errorHandler.handleException(e, stack),
      ));
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      _logger.info('Password reset email sent to $email');
    } catch (e, stack) {
      _logger.error('Password reset failed', e, stack);
      throw _errorHandler.handleException(e, stack);
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw const AppError(message: 'No user is logged in');
      }
      
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id);
      
      _logger.info('Profile updated successfully');

      // Refresh user data
      refreshUserData();
    } catch (e, stack) {
      _logger.error('Profile update failed', e, stack);
      throw _errorHandler.handleException(e, stack);
    }
  }

  // Refresh user data
  Future<void> refreshUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await _getUserProfile(user.id);
      final session = _supabase.auth.currentSession;

      state = AsyncData(AuthState(
        status: AuthStatus.authenticated,
        user: userProfile,
        session: session,
      ));
    } catch (e, stack) {
      _logger.error('Error refreshing user data', e, stack);
    }
  }
}
