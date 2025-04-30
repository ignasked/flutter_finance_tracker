part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final supabase.User? user; // Supabase User object

  const AuthState._({
    required this.status,
    this.user,
  });

  // Initial unknown state
  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  // Authenticated state
  const AuthState.authenticated(supabase.User user)
      : this._(status: AuthStatus.authenticated, user: user);

  // Unauthenticated state
  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  @override
  List<Object?> get props => [status, user];
}
