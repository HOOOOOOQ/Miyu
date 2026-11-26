import 'package:google_sign_in/google_sign_in.dart';

import '../config/app_config.dart';
import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_store.dart';
import '../models/user.dart';

class AuthResult {
  const AuthResult({required this.user, required this.isNewUser});
  final User user;
  final bool isNewUser;
}

/// Google Sign-In + Miyu session lifecycle.
///
/// The ID token is produced on device and verified server-side; the backend
/// then returns Miyu access/refresh tokens which live only in secure storage.
class AuthService {
  AuthService({required ApiClient api, required SecureStore secureStore, GoogleSignIn? googleSignIn})
      : _api = api,
        _secureStore = secureStore,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId: AppConfig.googleServerClientId.isEmpty
                  ? null
                  : AppConfig.googleServerClientId,
            );

  final ApiClient _api;
  final SecureStore _secureStore;
  final GoogleSignIn _googleSignIn;

  Future<AuthResult> signInWithGoogle() async {
    final GoogleSignInAccount? account;
    try {
      account = await _googleSignIn.signIn();
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('canceled') || message.contains('cancelled') || message.contains('12501')) {
        throw ApiException(message: 'Sign-in cancelled', code: 'SIGN_IN_CANCELLED');
      }
      if (message.contains('network')) {
        throw ApiException.network('Google sign-in needs an internet connection.');
      }
      throw ApiException(message: 'Google sign-in failed. Please try again.', code: 'GOOGLE_SIGN_IN_FAILED');
    }
    if (account == null) {
      throw ApiException(message: 'Sign-in cancelled', code: 'SIGN_IN_CANCELLED');
    }

    final tokens = await account.authentication;
    final idToken = tokens.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException(
        message: 'Google did not return an ID token. Check the OAuth client configuration '
            '(SHA-1/SHA-256 must be registered for package com.miyu.messaging).',
        code: 'MISSING_ID_TOKEN',
      );
    }

    final response = await _api.post(
      '/auth/google',
      data: {'idToken': idToken, 'deviceName': 'Miyu Android'},
    );
    final data = response['data'] as Map<String, dynamic>;
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _secureStore.saveSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user.id,
    );
    _api.setTokens(accessToken: data['accessToken'] as String);
    return AuthResult(user: user, isNewUser: data['isNewUser'] == true);
  }

  /// Attempts to restore an existing session using the stored refresh token.
  /// Returns the current user or null when no valid session exists.
  Future<User?> restoreSession() async {
    final accessToken = await _secureStore.readAccessToken();
    final refreshToken = await _secureStore.readRefreshToken();
    if (accessToken == null || refreshToken == null) return null;
    _api.setTokens(accessToken: accessToken);
    try {
      final response = await _api.get('/users/me');
      final data = response['data'] as Map<String, dynamic>;
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.isNotFound) {
        await _secureStore.clearSession();
        return null;
      }
      // Network issues: keep the session, but signal offline start.
      rethrow;
    }
  }

  Future<void> signOut({String? fcmToken}) async {
    final refreshToken = await _secureStore.readRefreshToken();
    try {
      await _api.post('/auth/logout', data: {
        if (refreshToken != null) 'refreshToken': refreshToken,
        if (fcmToken != null) 'fcmToken': fcmToken,
      });
    } catch (_) {
      // Logout must be local-first: never block sign-out on network failure.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _secureStore.clearSession();
    _api.setTokens(accessToken: null);
  }
}
