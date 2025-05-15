part of '../../front/auth/auth_bloc/auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Event to start listening to authentication state changes.
class AuthSubscriptionRequested extends AuthEvent {}

/// Internal event triggered when the authentication state changes from the stream.
class _AuthUserChanged extends AuthEvent {
  // Explicitly use the alias for Supabase AuthState
  final supabase.AuthState authState;

  const _AuthUserChanged(this.authState);

  @override
  List<Object?> get props => [authState];
}

/// Event to request user logout.
class AuthLogoutRequested extends AuthEvent {}
