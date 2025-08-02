// lib/providers/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onecup/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for the AuthRepository.
///
/// This centralizes access to authentication logic, making it easy to manage
/// and test. The UI will interact with this provider to perform auth actions.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client);
});

/// StreamProvider for authentication state changes.
///
/// This provider exposes the user's authentication state as a stream,
/// allowing the UI to reactively update when the user logs in or out.
/// It's the foundation for components like AuthGate.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});

/// Provider to get the current user object.
///
/// This provides a simple, direct way to access the currently logged-in
/// Supabase User object throughout the app.
final currentUserProvider = Provider<User?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.currentUser;
});
