import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabaseClient;

  AuthService(this._supabaseClient);

  // Expose the auth state stream
  Stream<AuthState> get authStateChanges =>
      _supabaseClient.auth.onAuthStateChange;

  // Get the current user
  User? get currentUser => _supabaseClient.auth.currentUser;

  // Sign up
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _supabaseClient.auth.signUp(email: email, password: password);
      // Supabase handles email verification flow if enabled in your project settings
    } on AuthException catch (e) {
      // Handle specific auth errors if needed, otherwise rethrow
      print('AuthService SignUp Error: ${e.message}');
      throw Exception('Sign up failed: ${e.message}');
    } catch (e) {
      print('AuthService SignUp Generic Error: $e');
      throw Exception('An unexpected error occurred during sign up.');
    }
  }

  // Log in
  Future<void> logIn({required String email, required String password}) async {
    try {
      await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      print('AuthService LogIn Error: ${e.message}');
      // Provide more user-friendly messages based on e.statusCode or e.message
      if (e.message.contains('Invalid login credentials')) {
        throw Exception('Invalid email or password.');
      }
      throw Exception('Login failed: ${e.message}');
    } catch (e) {
      print('AuthService LogIn Generic Error: $e');
      throw Exception('An unexpected error occurred during login.');
    }
  }

  // Log out
  Future<void> logOut() async {
    try {
      await _supabaseClient.auth.signOut();
    } catch (e) {
      print('AuthService LogOut Error: $e');
      // Decide if logout errors need specific handling
      throw Exception('Logout failed.');
    }
  }
}
