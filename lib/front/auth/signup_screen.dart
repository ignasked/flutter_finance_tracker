// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:money_owl/backend/services/auth_service.dart';
// import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
// import 'package:money_owl/front/auth/cubit/signup_cubit.dart';
// import 'package:formz/formz.dart';

// class SignupScreen extends StatelessWidget {
//   const SignupScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppStyle.backgroundColor, // Use AppStyle
//       appBar: AppBar(
//         title: const Text('Sign Up', style: AppStyle.heading2), // Use AppStyle
//         backgroundColor: AppStyle.primaryColor, // Use AppStyle
//         foregroundColor: Colors.white, // Keep white for AppBar
//       ),
//       body: BlocProvider(
//         create: (_) => SignupCubit(context.read<AuthService>()),
//         child: const _SignupForm(),
//       ),
//     );
//   }
// }

// class _SignupForm extends StatelessWidget {
//   const _SignupForm();

//   @override
//   Widget build(BuildContext context) {
//     return BlocListener<SignupCubit, SignupState>(
//       listener: (context, state) {
//         if (state.status.isSuccess) {
//           Navigator.of(context).pop(); // Go back after successful signup
//         } else if (state.status.isFailure) {
//           ScaffoldMessenger.of(context)
//             ..hideCurrentSnackBar()
//             ..showSnackBar(
//               SnackBar(
//                 content: Text(state.errorMessage ?? 'Sign Up Failed',
//                     style: AppStyle.bodyText
//                         .copyWith(color: Colors.white)), // Use AppStyle
//                 backgroundColor: AppStyle.expenseColor, // Use AppStyle
//               ),
//             );
//         }
//       },
//       child: Padding(
//         padding: const EdgeInsets.all(AppStyle.paddingLarge), // Use AppStyle
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             _EmailInput(),
//             const SizedBox(height: AppStyle.paddingMedium), // Use AppStyle
//             _PasswordInput(),
//             const SizedBox(height: AppStyle.paddingMedium), // Use AppStyle
//             _ConfirmPasswordInput(),
//             const SizedBox(height: AppStyle.paddingLarge), // Use AppStyle
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
//     return BlocBuilder<SignupCubit, SignupState>(
//       buildWhen: (previous, current) => previous.email != current.email,
//       builder: (context, state) {
//         return TextField(
//           key: const Key('signupForm_emailInput_textField'),
//           onChanged: (email) => context.read<SignupCubit>().emailChanged(email),
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
//     return BlocBuilder<SignupCubit, SignupState>(
//       buildWhen: (previous, current) => previous.password != current.password,
//       builder: (context, state) {
//         return TextField(
//           key: const Key('signupForm_passwordInput_textField'),
//           onChanged: (password) =>
//               context.read<SignupCubit>().passwordChanged(password),
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

// class _ConfirmPasswordInput extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<SignupCubit, SignupState>(
//       buildWhen: (previous, current) =>
//           previous.password != current.password ||
//           previous.confirmedPassword != current.confirmedPassword,
//       builder: (context, state) {
//         return TextField(
//           key: const Key('signupForm_confirmedPasswordInput_textField'),
//           onChanged: (confirmPassword) => context
//               .read<SignupCubit>()
//               .confirmedPasswordChanged(confirmPassword),
//           obscureText: true,
//           decoration: InputDecoration(
//             labelText: 'Confirm Password',
//             labelStyle: AppStyle.bodyText, // Use AppStyle
//             errorText: state.confirmedPassword.displayError != null
//                 ? 'Passwords do not match'
//                 : null,
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

// class _SignupButton extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return BlocBuilder<SignupCubit, SignupState>(
//       builder: (context, state) {
//         return state.status.isInProgress
//             ? const CircularProgressIndicator()
//             : ElevatedButton(
//                 key: const Key('signupForm_continue_raisedButton'),
//                 style: AppStyle.primaryButtonStyle, // Use AppStyle
//                 onPressed: state.isValid
//                     ? () => context.read<SignupCubit>().signUpFormSubmitted()
//                     : null,
//                 child: const Text('SIGN UP'),
//               );
//       },
//     );
//   }
// }
