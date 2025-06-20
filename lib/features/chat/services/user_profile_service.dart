import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_model.dart';

class UserProfileService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  final Map<String, UserModel> _profileCache = {};

  Future<UserModel?> getUserProfile(String userId) async {
    if (userId.isEmpty) return null;
    if (_profileCache.containsKey(userId)) {
      print("UserProfileService: Returning cached profile for $userId");
      return _profileCache[userId];
    }

    print("UserProfileService: Fetching profile for $userId from DB");
    try {
      final response = await _supabaseClient
          .from('profiles')
          .select('id, username, email, phone, profile_picture, chinese_phone_number, user_type')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print("UserProfileService: No profile found for $userId");
        return null;
      }
      
      final userModel = UserModel.fromMap(response);
      _profileCache[userId] = userModel; // Cache the fetched profile
      return userModel;
    } catch (e) {
      print("UserProfileService: Error fetching profile for $userId: $e");
      return null;
    }
  }

  void clearProfileCache(String userId) {
    _profileCache.remove(userId);
  }

  void clearAllProfileCache() {
    _profileCache.clear();
  }
} 