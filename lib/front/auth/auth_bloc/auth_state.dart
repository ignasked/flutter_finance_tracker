part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final supabase.User? user; // Supabase User object
  final bool isSyncing; // <-- Add this flag

  const AuthState._({
    required this.status,
    this.user,
    this.isSyncing = false, // <-- Default to false
  });

  // Initial unknown state
  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  // Authenticated state
  const AuthState.authenticated(supabase.User user,
      {bool isSyncing = false}) // <-- Add named param
      : this._(
            status: AuthStatus.authenticated,
            user: user,
            isSyncing: isSyncing); // <-- Pass value

  // Unauthenticated state
  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  @override
  List<Object?> get props => [status, user, isSyncing]; // <-- Include in props
}
