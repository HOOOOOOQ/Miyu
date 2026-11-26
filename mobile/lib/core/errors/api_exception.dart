/// Normalised error surface for every network and socket failure.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
    this.isNetworkError = false,
  });

  final String message;
  final String? code;
  final int? statusCode;
  final List<Map<String, dynamic>>? details;
  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isRateLimited => statusCode == 429;

  /// Human-friendly messages for the codes the backend can return.
  String get friendlyMessage {
    switch (code) {
      case 'INVALID_TOKEN':
      case 'MISSING_TOKEN':
        return 'Your session expired. Please sign in again.';
      case 'REFRESH_TOKEN_REUSE':
      case 'REFRESH_TOKEN_REVOKED':
        return 'Your session was ended for security. Please sign in again.';
      case 'INVALID_GOOGLE_TOKEN':
        return 'Google sign-in could not be verified. Please try again.';
      case 'GOOGLE_AUTH_NOT_CONFIGURED':
        return 'Google sign-in is not configured on the server yet.';
      case 'USERNAME_TAKEN':
        return 'That username is already taken. Try another one.';
      case 'USER_BLOCKED':
        return 'This user is no longer available.';
      case 'FILE_TOO_LARGE':
        return message;
      case 'MEDIA_NOT_CONFIGURED':
        return 'Media uploads are not configured on the server yet.';
      case 'CALL_IN_PROGRESS':
        return 'You are already on a call.';
      case 'NOT_A_PARTICIPANT':
        return 'You no longer have access to this conversation.';
      case 'RATE_LIMITED':
        return 'Too many attempts. Please wait a moment.';
      default:
        if (isNetworkError) {
          return 'Cannot reach Miyu servers. Check your connection.';
        }
        return message;
    }
  }

  static ApiException network(String message) => ApiException(
        message: message,
        code: 'NETWORK_ERROR',
        isNetworkError: true,
      );

  @override
  String toString() => 'ApiException($statusCode/$code): $message';
}
