class UserModel {
  final String id;
  final String email;
  final String? username;
  final String? phoneNumber;
  final String? chinesePhoneNumber;
  final String? userType;
  final String? profilePicture;
  final DateTime? dateOfBirth;
  final double walletBalance;
  final bool isEmailVerified;

  String? get avatarUrl => profilePicture;

  UserModel({
    required this.id,
    required this.email,
    this.username,
    this.phoneNumber,
    this.chinesePhoneNumber,
    this.userType,
    this.profilePicture,
    this.dateOfBirth,
    this.walletBalance = 0.0,
    this.isEmailVerified = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      username: map['username'] as String?,
      phoneNumber: map['phone'] as String?,
      chinesePhoneNumber: map['chinese_phone_number'] as String?,
      userType: map['user_type'] as String?,
      profilePicture: map['profile_picture'] as String?,
      dateOfBirth: map['date_of_birth'] != null
          ? DateTime.tryParse(map['date_of_birth'].toString())
          : null,
      walletBalance: (map['wallet_balance'] ?? 0.0).toDouble(),
      isEmailVerified: map['is_email_verified'] as bool? ?? map['email_confirmed_at'] != null ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'chinesePhoneNumber': chinesePhoneNumber,
      'userType': userType,
      'profilePicture': profilePicture,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'walletBalance': walletBalance,
      'isEmailVerified': isEmailVerified,
    };
  }
}
