import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

class AppError {
  final String message;
  final String? code;
  final dynamic exception;
  final StackTrace? stackTrace;

  const AppError({
    required this.message,
    this.code,
    this.exception,
    this.stackTrace,
  });

  @override
  String toString() => 'AppError: $message (code: $code)';
}

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final AppLogger _logger = AppLogger();

  AppError handleException(dynamic exception, [StackTrace? stackTrace]) {
    _logger.error('An error occurred', exception, stackTrace);

    // Handle Supabase specific errors
    if (exception is AuthException) {
      return AppError(
        message: exception.message,
        code: exception.statusCode?.toString(),
        exception: exception,
        stackTrace: stackTrace,
      );
    }

    // Handle PostgrestException
    if (exception is PostgrestException) {
      return AppError(
        message: exception.message,
        code: exception.code,
        exception: exception,
        stackTrace: stackTrace,
      );
    }

    // Handle general exceptions
    return AppError(
      message: exception?.toString() ?? 'An unexpected error occurred',
      exception: exception,
      stackTrace: stackTrace,
    );
  }

  void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Display network error handling dialog
  Future<void> showErrorDialog(BuildContext context, AppError error) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(error.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
