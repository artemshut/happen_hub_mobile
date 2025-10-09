import 'package:flutter/material.dart';

import '../models/group.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/json_api_parser.dart';

class GroupRepository {
  final ApiClient _client = ApiClient();
  final AuthService _auth = AuthService();

  Future<List<Group>> fetchGroups(BuildContext context) async {
    final token = await _auth.getToken();
    if (token == null) {
      throw Exception("No token found. Please log in.");
    }

    final res = await _client.get("/groups", token: token);
    if (res.statusCode == 200) {
      return JsonApiParser.parseGroups(res.body);
    } else if (res.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    } else {
      throw Exception("Failed to load groups (${res.statusCode})");
    }
  }
}
