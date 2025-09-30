import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  /// --- Save tokens ---
  Future<void> _saveTokens(String token, {String? refreshToken}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", token);
    if (refreshToken != null) {
      await prefs.setString("refresh_token", refreshToken);
    }
  }

  /// --- Email/Password login ---
  Future<bool> login(String email, String password) async {
    final res = await _client.post("/sessions", {
      "email": email,
      "password": password,
    });

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final token = body["data"]["attributes"]["token"];
      final refreshToken = body["data"]["attributes"]["refresh_token"];

      if (token != null) {
        await _saveTokens(token, refreshToken: refreshToken);
        return true;
      }
    }
    return false;
  }

  /// --- Google login with ID token ---
  Future<bool> googleLogin(String idToken) async {
    final url = Uri.parse("https://happenhub.co/users/google_mobile_login");

    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id_token": idToken}),
    );

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final token = body["token"];
      final refreshToken = body["refresh_token"]; // if provided by BE

      if (token != null) {
        await _saveTokens(token, refreshToken: refreshToken);
        return true;
      }
    } else {
      print("❌ Google login failed: ${res.statusCode} - ${res.body}");
    }
    return false;
  }

  /// --- Get current user ---
  Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    final res = await _client.get("/me", token: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return User.fromJson(body['data']);
    } else if (res.statusCode == 401) {
      // Token expired → logout
      await logout();
    }
    return null;
  }

  /// --- Token helpers ---
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("refresh_token");
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  /// --- Logout ---
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("refresh_token");
  }
}