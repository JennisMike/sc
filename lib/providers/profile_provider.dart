import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/logger.dart';

/// State class for user profile
class ProfileState {
  final bool isLoading;
  final UserModel? profile;
  final String? error;
  final bool isDarkMode;

  const ProfileState({
    this.isLoading = false,
    this.profile,
    this.error,
    this.isDarkMode = false,
  });

  ProfileState copyWith({
    bool? isLoading,
    UserModel? profile,
    String? error,
    bool? isDarkMode,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: error ?? this.error,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

/// Profile repository to manage user profile data
class ProfileRepository extends StateNotifier<ProfileState> {
  final AuthService _authService;
  final AppLogger _logger;
  final SharedPreferences _prefs;

  ProfileRepository(this._authService, this._logger, this._prefs)
      : super(ProfileState(
          isDarkMode: _prefs.getBool('darkMode') ?? false,
        ));

  /// Load user profile data
  Future<void> loadUserProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // First try to load from local storage for faster UI display
      await _loadLocalUserData();
      
      // Then load fresh data from backend
      final supabaseUser = _authService.currentUser;
      if (supabaseUser != null) {
        final userId = supabaseUser.id;
        final userData = await _authService.getUserProfile(userId);
        if (userData != null) {
          final user = UserModel.fromMap(userData);
          await _saveUserDataLocally(user);
          state = state.copyWith(profile: user, isLoading: false);
        } else {
          state = state.copyWith(error: 'Failed to load user profile', isLoading: false);
        }
      } else {
        state = state.copyWith(error: 'User not logged in', isLoading: false);
      }
    } catch (e) {
      _logger.error('Error loading user profile', e);
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Save user data to local storage
  Future<void> _saveUserDataLocally(UserModel user) async {
    try {
      await _prefs.setString('user_profile', jsonEncode(user.toJson()));
    } catch (e) {
      _logger.error('Error saving user data locally', e);
    }
  }

  /// Load user data from local storage
  Future<void> _loadLocalUserData() async {
    try {
      final userData = _prefs.getString('user_profile');
      if (userData != null) {
        final userMap = Map<String, dynamic>.from(
            Map<String, dynamic>.from(jsonDecode(userData)));
        state = state.copyWith(
          profile: UserModel.fromMap(userMap),
          isLoading: true, // Keep loading true as we're still fetching from backend
        );
      }
    } catch (e) {
      _logger.error('Error loading local user data', e);
    }
  }

  /// Toggle dark mode
  Future<void> toggleDarkMode(bool value) async {
    try {
      await _prefs.setBool('darkMode', value);
      state = state.copyWith(isDarkMode: value);
    } catch (e) {
      _logger.error('Error toggling dark mode', e);
    }
  }
}

/// Provider for FlutterLocalNotificationsPlugin
final localNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('localNotificationsPluginProvider not overridden');
});

/// Provider for shared preferences
final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Should be initialized in main.dart');
});

/// Provider for profile repository
final profileRepositoryProvider = StateNotifierProvider<ProfileRepository, ProfileState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final logger = AppLogger();
  final prefs = ref.watch(sharedPrefsProvider);
  return ProfileRepository(authService, logger, prefs);
});

/// Provider for user profile
final userProfileProvider = Provider<UserModel?>((ref) {
  return ref.watch(profileRepositoryProvider).profile;
});

/// Provider for wallet balance
final walletBalanceProvider = Provider<double>((ref) {
  final profile = ref.watch(userProfileProvider);
  return profile?.walletBalance ?? 0.0;
});

/// Provider for dark mode setting
final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(profileRepositoryProvider).isDarkMode;
});
