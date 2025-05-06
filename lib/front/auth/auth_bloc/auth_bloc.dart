import 'dart:async';
import 'dart:ffi';
import 'dart:ui';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;
  final SyncService _syncService;
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final VoidCallback? _onSyncComplete;

  StreamSubscription<supabase.AuthState>? _authStateSubscription;

  AuthBloc({
    required AuthService authService,
    required SyncService syncService,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    VoidCallback? onSyncComplete,
  })  : _authService = authService,
        _syncService = syncService,
        _transactionRepository = transactionRepository,
        _accountRepository = accountRepository,
        _categoryRepository = categoryRepository,
        _onSyncComplete = onSyncComplete,
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

    final previousStatus = state.status;
    final newStatus =
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;

    // Optimization: If status and user haven't changed, do nothing.
    if (newStatus == previousStatus && state.user?.id == user?.id) {
      print(
          "AuthBloc: Auth state unchanged ($newStatus, user: ${user?.id}), skipping processing.");
      return;
    }

    if (user != null) {
      print('AuthBloc: User Authenticated - ${user.id}');
      // Emit authenticated state immediately, but without sync flag yet
      // Check if we are already authenticated to avoid unnecessary emits if only user object changed slightly
      if (previousStatus != AuthStatus.authenticated) {
        emit(AuthState.authenticated(user, isSyncing: false));
      }

      // Perform assignment and sync only if transitioning *to* authenticated
      if (previousStatus != AuthStatus.authenticated) {
        try {
          print('AuthBloc: Assigning local data to user ${user.id}...');
          int txUpdated =
              await _transactionRepository.assignUserIdToNullEntries(user.id);
          int accUpdated =
              await _accountRepository.assignUserIdToNullEntries(user.id);
          int catUpdated =
              await _categoryRepository.assignUserIdToNullEntries(user.id);
          print(
              'AuthBloc: Assigned user ID to $txUpdated transactions, $accUpdated accounts, $catUpdated categories.');

          print(
              'AuthBloc: Triggering sync after authentication and data assignment...');

          // --- Show Sync Indicator ---
          // Ensure we emit the state with the *current* user object
          emit(AuthState.authenticated(user, isSyncing: true));
          print('AuthBloc: Emitted isSyncing: true');

          // REMOVED onSyncEnd parameter from syncAll call
          await _syncService.syncAll();
          print('AuthBloc: Sync completed successfully.');

          _onSyncComplete?.call(); // This signals the UI layer to refresh
          print('AuthBloc: onSyncComplete callback invoked.');

          // --- Hide Sync Indicator ---
          // Emit false *after* sync and refresh trigger
          // Ensure we emit the state with the *current* user object
          emit(AuthState.authenticated(user, isSyncing: false));
          print('AuthBloc: Emitted isSyncing: false');
        } catch (e, stacktrace) {
          print(
              'AuthBloc: Failed during post-authentication steps (assignment or sync): $e');
          print(stacktrace);
          // Ensure sync indicator is hidden even on error
          // Check current state before emitting to avoid issues if state changed rapidly
          if (state.status == AuthStatus.authenticated && state.isSyncing) {
            // Ensure we emit the state with the *current* user object
            emit(AuthState.authenticated(user, isSyncing: false));
            print('AuthBloc: Emitted isSyncing: false after error.');
          }
          // Optionally call _onSyncComplete even on error? Depends on desired behavior.
          // _onSyncComplete?.call();
        }
      } else {
        print('AuthBloc: User already authenticated, skipping migration/sync.');
        // If the user was already authenticated, trigger the refresh callback
        // as data might be stale from a previous session.
        _onSyncComplete?.call();
        print(
            'AuthBloc: User already authenticated, triggered onSyncComplete for potential refresh.');
      }
    } else {
      // --- MODIFICATION START ---
      // Always emit unauthenticated if user is null, regardless of previous state.
      // This handles both logout transitions and initial startup when not logged in.
      print('AuthBloc: User is null. Emitting Unauthenticated.');
      emit(const AuthState.unauthenticated());
      // Add any necessary cleanup logic for logout here if needed
      // --- MODIFICATION END ---
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
