part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final supabase.User? user;
  final bool isDataInitialized;

  const AuthState._({
    required this.status,
    this.user,
    this.isDataInitialized = false,
  });

  const AuthState.unknown() : this._(status: AuthStatus.unknown);

  const AuthState.authenticated(supabase.User user,
      {bool isDataInitialized = false})
      : this._(
            status: AuthStatus.authenticated,
            user: user,
            isDataInitialized: isDataInitialized);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  AuthState copyWith({
    AuthStatus? status,
    supabase.User? user,
    bool? isDataInitialized,
  }) {
    return AuthState._(
      status: status ?? this.status,
      user: user ?? this.user,
      isDataInitialized: isDataInitialized ?? this.isDataInitialized,
    );
  }

  @override
  List<Object?> get props => [status, user, isDataInitialized];
}
