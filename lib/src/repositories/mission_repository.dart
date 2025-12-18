import 'dart:convert';

import '../models/mission.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class MissionRepository {
  final ApiClient _client = ApiClient();
  final AuthService _auth = AuthService();

  Future<List<UserMission>> fetchMissions() async {
    final token = await _auth.getToken();
    if (token == null) return const [];

    final res = await _client.get("/missions", token: token);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? const [];
      return data
          .map((item) => UserMission.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    throw Exception("Failed to load missions (${res.statusCode})");
  }
}
