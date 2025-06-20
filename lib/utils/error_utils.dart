import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'error_handler.dart';
import 'logger.dart';

/// Utility class for handling errors throughout the application
class ErrorUtils {
  static final _logger = AppLogger();

  /// Shows an error snackbar with appropriate message based on error type
  static void showErrorSnackBar(BuildContext context, dynamic error) {
    final errorMessage = getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Logs the error with appropriate context
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    _logger.error('$context: ${getErrorMessage(error)}', error, stackTrace);
  }

  /// Gets a user-friendly error message based on error type
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return _getAuthErrorMessage(error);
    } else if (error is PostgrestException) {
      return 'Database error: ${error.message}';
    } else if (error is AppError) {
      return error.message;
    } else {
      return error?.toString() ?? 'An unknown error occurred';
    }
  }

  /// Gets specific error message for authentication errors
  static String _getAuthErrorMessage(AuthException error) {
    switch (error.statusCode) {
      case '400':
        return 'Invalid email or password';
      case '401':
        return 'You are not authorized to perform this action';
      case '403':
        return 'Access denied';
      case '404':
        return 'User not found';
      case '409':
        return 'User already exists with this email';
      case '422':
        return 'Validation error: ${error.message}';
      case '429':
        return 'Too many requests. Please try again later.';
      case '500':
        return 'Server error. Please try again later.';
      default:
        return error.message;
    }
  }

  /// Handles common authentication errors and performs actions
  static void handleAuthError(BuildContext context, dynamic error) {
    logError('Authentication error', error);
    showErrorSnackBar(context, error);
    
    // Handle specific auth errors like session expiration
    if (error is AuthException && error.statusCode == '401') {
      // Could navigate to login screen here if needed
    }
  }
}
