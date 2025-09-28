import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiClient {
  final String baseUrl = "https://happenhub.co/api/v1";

  /// Basic GET
  Future<http.Response> get(String path, {String? token}) async {
    return http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(token),
    );
  }

  Future<http.Response> post(String path, Map<String, dynamic> body,
      {String? token}) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(token),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String path, Map<String, dynamic> body,
      {String? token}) async {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(token),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path, {String? token}) async {
    return http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(token),
    );
  }

  /// --- Helpers ---
  Future<Map<String, String>> _headers(String? token) async {
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }
}