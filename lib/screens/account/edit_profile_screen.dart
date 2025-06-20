import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, User;
import 'package:storage_client/storage_client.dart';
import '../../models/user_model.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel userProfile;

  const EditProfileScreen({
    Key? key,
    required this.userProfile,
  }) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _chinesePhoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedUserType;
  File? _avatarFile;
  bool _saving = false;
  // Initialize with the value from userProfile
  // late final bool _isEmailVerified; // Email verification handled elsewhere
  final _supabase = Supabase.instance.client;

  final List<String> _userTypes = ['student', 'worker']; // Options for dropdown

  @override
  void initState() {
    super.initState();
    // _isEmailVerified = widget.userProfile.isEmailVerified; // Email verification handled elsewhere
    _usernameController.text = widget.userProfile.username ?? '';
    _phoneController.text = widget.userProfile.phoneNumber ?? '';
    _chinesePhoneController.text = widget.userProfile.chinesePhoneNumber ?? '';
    _emailController.text = widget.userProfile.email ?? '';
    _selectedUserType = widget.userProfile.userType;
    if (_selectedUserType != null && !_userTypes.contains(_selectedUserType)) {
      _selectedUserType = null;
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    try {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
    );

    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final User? user = _supabase.auth.currentUser;
      if (user == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated. Cannot save profile.')),
          );
        }
        setState(() => _saving = false);
        return;
      }

      final username = _usernameController.text.trim();
      final phone = _phoneController.text.trim();
      final chinesePhone = _chinesePhoneController.text.trim();
      final userType = _selectedUserType;
      final email = _emailController.text.trim();

      final Map<String, dynamic> profileUpdateData = {
          'id': user.id,
          'username': username,
        'email': email,
        'phone': phone.isNotEmpty ? phone : null,
        'chinese_phone_number': chinesePhone.isNotEmpty ? chinesePhone : null,
        'user_type': userType,
      };

      await _supabase.from('profiles').upsert(profileUpdateData);
      print("Profile data upserted: $profileUpdateData");

        if (_avatarFile != null) {
        final fileExt = _avatarFile!.path.split('.').last.toLowerCase();
        final fileName = '${user.id}_avatar.$fileExt';
        print("Attempting to upload avatar: $fileName to bucket 'avatars'");
        
          await _supabase.storage
              .from('avatars')
            .upload(fileName, _avatarFile!, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));

        print("Avatar upload completed for path: $fileName");

          final String publicUrl = _supabase.storage
              .from('avatars')
              .getPublicUrl(fileName);
        print("Avatar public URL: $publicUrl");

          await _supabase
              .from('profiles')
              .update({'profile_picture': publicUrl}).eq('id', user.id);
        print("Profile picture URL updated in profiles table.");
        }

        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _chinesePhoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _avatarFile != null
                      ? FileImage(_avatarFile!)
                      : (widget.userProfile.avatarUrl?.isNotEmpty == true
                          ? NetworkImage(widget.userProfile.avatarUrl!)
                          : null) as ImageProvider?,
                  child: (widget.userProfile.avatarUrl?.isEmpty ?? true) &&
                      _avatarFile == null
                      ? const Icon(Icons.person, size: 40)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Email (Read-only)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: theme.disabledColor.withOpacity(0.1),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number (Local)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixText: '+237 ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _chinesePhoneController,
              decoration: InputDecoration(
                labelText: 'Chinese Phone Number (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixText: '+86 ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedUserType,
              decoration: InputDecoration(
                labelText: 'I am a... (Optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: _userTypes.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value[0].toUpperCase() + value.substring(1)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedUserType = newValue;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
} 