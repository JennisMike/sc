import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Check if user is logged in
  bool get isLoggedIn => _supabase.auth.currentUser != null;

  // Get current user ID
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // Stream of auth changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  // Sign in with email and password
  Future<AuthResponse> loginWithEmail(String email, String password) async {
    try {
      print('Signing in with email: ${email.trim()}');
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print('Sign in successful: ${response.user?.id}');
      return response;
    } catch (e) {
      print('Error in loginWithEmail: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      print('Signing up with email: ${email.trim()}');
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {
          'username': email.trim(),
          'display_name': email.trim().split('@').first,
        },
      );
      print('Sign up successful: ${response.user?.id}');

      // Insert profile into the database if user was created
      if (response.user != null) {
        try {
          await _supabase.from('profiles').insert({
            'id': response.user!.id,
            'email': email.trim(),
            'username': email.trim(),
            'wallet_balance': 0.0,
          });
          print('Profile created successfully');
        } catch (e) {
          print('Error creating profile: $e');
        }

        // Explicitly sign in to ensure session is immediately available
        if (_supabase.auth.currentSession == null) {
          print('No session detected after signup, explicitly signing in...');
          await _supabase.auth.signInWithPassword(
            email: email.trim(),
            password: password.trim(),
          );
          print('Explicit sign in completed');
        }
      }
      return response;
    } catch (e) {
      print('Error in signUpWithEmail: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      print('User signed out successfully');
    } catch (e) {
      print('Error in logout: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email.trim());
      print('Password reset email sent to $email');
    } catch (e) {
      print('Error in resetPassword: $e');
      rethrow;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    try {
      if (currentUserId == null) {
        throw Exception('No user is logged in');
      }
      
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUserId!);
      
      print('Profile updated successfully');
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      if (userId.isEmpty) {
        throw Exception('User ID cannot be empty');
      }
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
          
      return response;
    } catch (e) {
      if (e is PostgrestException && e.code == 'PGRST116') {
        // No rows returned
        return null;
      }
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Get current user profile
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (currentUserId == null) return null;
    return getUserProfile(currentUserId!);
  }

  // Future<WeChatLoginResult> weChatLogin({
  //   required String appId,
  //   String? scope,
  // }) async {
  //   try {
  //     final result = await loginByWeChat(
  //       appId: appId,
  //       scope: scope ?? 'snsapi_userinfo',
  //     );
  //     return result;
  //   } catch (e) {
  //     print('Error in weChatLogin: $e');
  //     rethrow;
  //   }
  // }

  // Future<void> loginWithWeChat() async {
  //   try {
  //     final result = await weChatLogin(
  //       appId: WECHAT_APP_ID,
  //       scope: 'snsapi_userinfo',
  //     );
  //     print('WeChat login result: $result');
  //     // Handle WeChat login result and create/update user profile
  //   } catch (e) {
  //     print('Error in loginWithWeChat: $e');
  //     rethrow;
  //   }
  // }

  // Future<void> signUpWithWeChat() async {
  //   try {
  //     final result = await weChatLogin(
  //       appId: WECHAT_APP_ID,
  //       scope: 'snsapi_userinfo',
  //     );
  //     print('WeChat signup result: $result');
  //     // Handle WeChat signup result and create/update user profile
  //   } catch (e) {
  //     print('Error in signUpWithWeChat: $e');
  //     rethrow;
  //   }
  // }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final supabaseAuthStreamProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.onAuthStateChange;
});
