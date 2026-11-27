import 'package:shared_preferences/shared_preferences.dart';
import 'package:miyu/domain/models.dart';

/// AuthService — YouTube Music OAuth token (original auth provider),
/// local account store. No credentials in logs.
class AuthService {
  static const String kToken = 'account_token';
  static const String kUsername = 'account_username';
  static const String kRole = 'account_role'; // 'user' | 'admin'
  static const String kVerified = 'account_verified';

  /// Store a YouTube Music token (reused from original app's OAuth flow).
  static Future<void> signInYt(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kToken, token);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kToken);
    await prefs.remove(kUsername);
  }

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(kToken);
    return t != null && t.isNotEmpty;
  }

  static Future<UserAccount?> loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(kToken);
    if (token == null || token.isEmpty) return null;
    return UserAccount(
      id: prefs.getString(kUsername) ?? 'local-user',
      username: prefs.getString(kUsername) ?? 'local-user',
      displayName: prefs.getString(kUsername) ?? 'Local User',
      role: prefs.getString(kRole) ?? 'user',
      verified: prefs.getBool(kVerified) ?? false,
      admin: prefs.getString(kRole) == 'admin',
    );
  }

  /// Server-side validation hook when an auth backend is available (reserved).
  static Future<void> validateTokenOnServer() async {
    // Reserved: when a backend exists, call AuthService.serverValidate(token).
  }
}
