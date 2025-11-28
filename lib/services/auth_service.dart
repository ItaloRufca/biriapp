import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((event) {
      notifyListeners();
    });
  }

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  User? get currentUser => _supabase.auth.currentUser;

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    notifyListeners();
    return response;
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    notifyListeners();
    return response;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    notifyListeners();
  }

  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'http://localhost:3000',
        );
        notifyListeners();
        return true;
      } else {
        // Mobile Google Sign In using Supabase OAuth with Deep Link
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.flutterquickstart://login-callback',
        );
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return false;
    }
  }

  Future<void> updateProfile({String? username, String? avatarUrl}) async {
    final updates = {
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    if (updates.isNotEmpty) {
      await _supabase.auth.updateUser(UserAttributes(data: updates));
      notifyListeners();
    }
  }
}
