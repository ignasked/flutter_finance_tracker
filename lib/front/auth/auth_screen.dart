import 'package:flutter/material.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';

class AuthScreen extends StatelessWidget {
  final bool isMandatory; // <-- Add flag

  const AuthScreen({
    super.key,
    this.isMandatory = true, // <-- Default to false
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Change title based on flag
      appBar: AppBar(
          title: Text(isMandatory ? 'Login Required' : 'Login / Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Conditionally show explanation text
              if (isMandatory) ...[
                Text(
                  "Welcome Back!",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "To keep your existing data safe and enable syncing, please log in or create an account.",
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
              ],
              SupaEmailAuth(
                // Keep existing callbacks
                onSignInComplete: (response) {
                  print('Sign in complete');
                  // No navigation needed here, AuthBloc state change handles it
                },
                onSignUpComplete: (response) {
                  print('Sign up complete');
                  if (response.session == null && response.user != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please check your email to confirm your account.'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                  // No navigation needed here
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
                    'owlandroid://com.games_from_garage.money_owl', // Redirect URL
                onSuccess: (Session session) {
                  print('Social sign in successful');
                  // No navigation needed here
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
