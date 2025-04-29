import 'package:flutter/material.dart';

/// A reusable loading widget that displays a spinner, an optional message, and an icon.
class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({Key? key, this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7), // Semi-transparent background
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/icons/receipt_scan_icon.png', // Path to the icon
              height: 100,
              width: 100,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A utility function to show the fullscreen loading popup.
void showLoadingPopup(BuildContext context, {String? message}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      insetPadding: EdgeInsets.zero, // Make the dialog fullscreen
      backgroundColor: Colors.transparent,
      child: LoadingWidget(message: message),
    ),
  );
}

/// A utility function to hide the loading popup.
void hideLoadingPopup(BuildContext context) {
  Navigator.of(context, rootNavigator: true).pop();
}
