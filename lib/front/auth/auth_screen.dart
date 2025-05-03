import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          // Added SingleChildScrollView for smaller screens
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center, // Center content vertically
            crossAxisAlignment:
                CrossAxisAlignment.stretch, // Stretch buttons horizontally
            children: [
              SupaEmailAuth(
                onSignInComplete: (response) {
                  // AuthBloc listener handles state change, just pop screen
                  print('Sign in complete');
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                },
                onSignUpComplete: (response) {
                  // AuthBloc listener handles state change if auto-confirm is on
                  print('Sign up complete');
                  if (response.session == null && response.user != null) {
                    // Needs email confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please check your email to confirm your account.'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                    if (Navigator.canPop(context)) {
                      Navigator.of(context)
                          .pop(); // Pop even if confirmation needed
                    }
                  } else if (Navigator.canPop(context)) {
                    // Auto-confirmed or already logged in
                    Navigator.of(context).pop();
                  }
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Authentication Error: ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              SupaSocialsAuth(
                socialProviders: const [
                  OAuthProvider.google,
                  // Add other providers like OAuthProvider.apple, etc.
                ],
                colored: true,
                redirectUrl:
                    'owlandroid://com.games_from_garage.money_owl', // Your redirect URL
                onSuccess: (Session session) {
                  // AuthBloc listener handles state change, just pop screen
                  print('Social sign in successful');
                  if (Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                },
                onError: (error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Social Auth Error: ${error.toString()}'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
