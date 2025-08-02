
// lib/repositories/auth_repository.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles all authentication and user management related tasks.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  /// Gets the current logged-in user.
  User? get currentUser => _client.auth.currentUser;

  /// Provides a stream of authentication state changes.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Signs up a new user.
  Future<AuthResponse> signUp({required String email, required String password}) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Signs in a user.
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(password: password, email: email);
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Updates the user's metadata (e.g., nickname, avatar URL).
  Future<UserResponse> updateUserMetadata(Map<String, dynamic> data) async {
    return await _client.auth.updateUser(UserAttributes(data: data));
  }

  /// Uploads an avatar image to Supabase Storage.
  Future<String> uploadAvatar(String filePath, String userId) async {
    final file = File(filePath);
    final fileExtension = filePath.split('.').last.toLowerCase();
    final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final bucketName = 'onecup';

    try {
      await _client.storage.from(bucketName).upload(
        fileName,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      return _client.storage.from(bucketName).getPublicUrl(fileName);
    } catch (e) {
      if (kDebugMode) {
        print('AuthRepository: Error uploading avatar: $e');
      }
      throw Exception('头像上传失败: $e');
    }
  }

  /// Gets the user's nickname from metadata.
  String? getUserNickname(User? user) {
    return user?.userMetadata?['nickname'] as String?;
  }

  /// Gets the user's avatar URL from metadata.
  String? getAvatarUrl(User? user) {
    return user?.userMetadata?['avatar_url'] as String?;
  }
}
