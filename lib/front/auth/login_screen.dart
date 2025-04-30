// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:money_owl/backend/services/auth_service.dart';
// import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
// import 'package:money_owl/front/auth/cubit/login_cubit.dart';
// import 'package:formz/formz.dart';
// import 'package:money_owl/front/auth/signup_screen.dart';

// class LoginScreen extends StatelessWidget {
//   const LoginScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppStyle.backgroundColor, // Use AppStyle
//       appBar: AppBar(
//         title: const Text('Login', style: AppStyle.heading2), // Use AppStyle
//         backgroundColor: AppStyle.primaryColor, // Use AppStyle
//         foregroundColor: Colors.white, // Keep white for AppBar
//       ),
//       body: BlocProvider(
//         create: (_) => LoginCubit(context.read<AuthService>()),
//         child: const _LoginForm(),
//       ),
//     );
//   }
// }

// class _LoginForm extends StatelessWidget {
//   const _LoginForm();

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<LoginCubit, LoginState>(
//       listener: (context, state) {
//         if (state.status.isFailure) {
//           ScaffoldMessenger.of(context)
//             ..hideCurrentSnackBar()
//             ..showSnackBar(
//               SnackBar(
//                 content: Text(state.errorMessage ?? 'Authentication Failure',
//                     style: AppStyle.bodyText
//                         .copyWith(color: Colors.white)), // Use AppStyle
//                 backgroundColor: AppStyle.expenseColor, // Use AppStyle
//               ),
//             );
//         }
//         // No need to handle success here as the AuthBloc listener in main.dart handles navigation
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(AppStyle.paddingLarge), // Use AppStyle
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             _EmailInput(),
//             const SizedBox(height: AppStyle.paddingMedium), // Use AppStyle
//             _PasswordInput(),
//             const SizedBox(height: AppStyle.paddingLarge), // Use AppStyle
//             _LoginButton(),
//             const SizedBox(height: AppStyle.paddingSmall), // Use AppStyle
//             _SignupButton(),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _EmailInput extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<LoginCubit, LoginState>(
//       buildWhen: (previous, current) => previous.email != current.email,
//       builder: (context, state) {
//         return TextField(
//           key: const Key('loginForm_emailInput_textField'),
//           onChanged: (email) => context.read<LoginCubit>().emailChanged(email),
//           keyboardType: TextInputType.emailAddress,
//           decoration: InputDecoration(
//             labelText: 'Email',
//             labelStyle: AppStyle.bodyText, // Use AppStyle
//             errorText:
//                 state.email.displayError != null ? 'Invalid email' : null,
//             border: OutlineInputBorder(
//               // Use AppStyle border
//               borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
//             ),
//             focusedBorder: OutlineInputBorder(
//               // Use AppStyle focused border
//               borderSide:
//                   const BorderSide(color: AppStyle.primaryColor, width: 2.0),
//               borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
//             ),
//             errorStyle:
//                 const TextStyle(color: AppStyle.expenseColor), // Use AppStyle
//           ),
//           style: AppStyle.bodyText, // Use AppStyle
//         );
//       },
//     );
//   }
// }

// class _PasswordInput extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<LoginCubit, LoginState>(
//       buildWhen: (previous, current) => previous.password != current.password,
//       builder: (context, state) {
//         return TextField(
//           key: const Key('loginForm_passwordInput_textField'),
//           onChanged: (password) =>
//               context.read<LoginCubit>().passwordChanged(password),
//           obscureText: true,
//           decoration: InputDecoration(
//             labelText: 'Password',
//             labelStyle: AppStyle.bodyText, // Use AppStyle
//             errorText:
//                 state.password.displayError != null ? 'Invalid password' : null,
//             border: OutlineInputBorder(
//               // Use AppStyle border
//               borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
//             ),
//             focusedBorder: OutlineInputBorder(
//               // Use AppStyle focused border
//               borderSide:
//                   const BorderSide(color: AppStyle.primaryColor, width: 2.0),
//               borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
//             ),
//             errorStyle:
//                 const TextStyle(color: AppStyle.expenseColor), // Use AppStyle
//           ),
//           style: AppStyle.bodyText, // Use AppStyle
//         );
//       },
//     );
//   }
// }

// class _LoginButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<LoginCubit, LoginState>(
//       builder: (context, state) {
//         return state.status.isInProgress
//             ? const CircularProgressIndicator()
//             : ElevatedButton(
//                 key: const Key('loginForm_continue_raisedButton'),
//                 style: AppStyle.primaryButtonStyle, // Use AppStyle
//                 onPressed: state.isValid
//                     ? () => context.read<LoginCubit>().logInWithCredentials()
//                     : null,
//                 child: const Text('LOGIN'),
//               );
//       },
//     );
//   }
// }

// class _SignupButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return TextButton(
//       key: const Key('loginForm_createAccount_flatButton'),
//       onPressed: () => Navigator.of(context).push<void>(
//         MaterialPageRoute(builder: (context) => const SignupScreen()),
//       ),
//       style: AppStyle.secondaryButtonStyle.copyWith(
//           // Use AppStyle
//           padding: MaterialStateProperty.all(EdgeInsets.zero)),
//       child: const Text(
//         'CREATE ACCOUNT',
//       ),
//     );
//   }
// }
