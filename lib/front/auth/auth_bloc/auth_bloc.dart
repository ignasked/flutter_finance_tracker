import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final SyncService _syncService;
  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  AuthBloc({required AuthService authService, required SyncService syncService})
      : _authService = authService,
        _syncService = syncService,
        super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<_AuthUserChanged>(_onUserChanged);
    on<AuthLogoutRequested>(_onLogoutRequested);

    add(AuthSubscriptionRequested());
  }

  void _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) {
    _authStateSubscription?.cancel();
    _authStateSubscription = _authService.authStateChanges.listen(
      (supabase.AuthState authState) {
        if (!isClosed) {
          add(_AuthUserChanged(authState));
        }
      },
      onError: (error) {
        print('AuthBloc: Error in authStateChanges stream: $error');
      },
      onDone: () {
        print('AuthBloc: authStateChanges stream completed.');
      },
      cancelOnError: false,
    );
  }

  Future<void> _onUserChanged(
    _AuthUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    final supabase.Session? session = event.authState.session;
    final supabase.User? user = session?.user;

    if (user != null) {
      print('AuthBloc: User Authenticated - ${user.id}');
      emit(AuthState.authenticated(user));
      try {
        print('AuthBloc: Triggering sync after authentication...');
        await _syncService.syncAll();
        print('AuthBloc: Sync completed successfully.');
      } catch (e) {
        print('AuthBloc: Sync failed after authentication: $e');
      }
    } else {
      print('AuthBloc: User Unauthenticated');
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.logOut();
      print('AuthBloc: Logout successful.');
    } catch (e) {
      print('AuthBloc: Logout failed: $e');
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
