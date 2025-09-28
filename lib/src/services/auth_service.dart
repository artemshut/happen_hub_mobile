// lib/services/auth_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../models/user.dart';

class AuthService {
  final ApiClient _client = ApiClient();

  Future<bool> login(String email, String password) async {
    final res = await _client.post("/sessions", {
      "email": email,
      "password": password,
    });

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final token = body["data"]["attributes"]["token"];
      final refreshToken = body["data"]["attributes"]["refresh_token"];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);
      await prefs.setString("refresh_token", refreshToken);

      return true;
    }
    return false;
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) return null;

    final res = await _client.get("/me", token: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      return User.fromJson(body['data']);
    } else if (res.statusCode == 401) {
      await logout();
      return null;
    }

    return null;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("refresh_token");
  }

  Future<bool> googleLogin(String idToken) async {
    final url = Uri.parse("https://happenhub.co/users/google_mobile_login");

    final response = await http.post(
      url,
      headers: { "Content-Type": "application/json" },
      body: jsonEncode({ "id_token": idToken }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final token = body["token"];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token);
      return true;
    } else {
      print("❌ Google login failed: ${response.statusCode} ${response.body}");
      return false;
    }
  }
}