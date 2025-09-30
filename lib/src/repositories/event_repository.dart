import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../services/api_client.dart';
import '../models/event.dart';
import '../services/json_api_parser.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';

class EventRepository {
  final ApiClient _client = ApiClient();
  final AuthService _authService = AuthService();

  Future<List<Event>> fetchEvents(BuildContext context) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final res = await _client.get("/events", token: token);
    print("🔎 [fetchEvents] Status: ${res.statusCode}");
    print("🔎 [fetchEvents] Body: ${res.body}");
    if (res.statusCode == 200) {
      return JsonApiParser.parseEvents(res.body);
    } else if (res.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    } else {
      throw Exception("Failed to load events (${res.statusCode})");
    }
  }

  Future<Event> fetchEvent(BuildContext context, String id) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final res = await _client.get("/events/$id", token: token);
    if (res.statusCode == 200) {
      return JsonApiParser.parseEvent(res.body);
    } else if (res.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    } else {
      throw Exception("Failed to load event (${res.statusCode})");
    }
  }

  Future<void> updateRsvp(BuildContext context, String eventId, String status) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final res = await _client.post("/events/$eventId/rsvp", {"status": status}, token: token);
    if (res.statusCode != 200) {
      throw Exception("RSVP failed (${res.statusCode})");
    }
  }

  /// ✅ Create new event
  Future<Event> createEvent({
  required String title,
  required String description,
  required DateTime startTime,
  DateTime? endTime,
  String? location,
  double? latitude,
  double? longitude,
  File? coverImage,
  List<File>? files,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final uri = Uri.parse("${_client.baseUrl}/events");
    final request = http.MultipartRequest("POST", uri);

    // Auth
    request.headers['Authorization'] = "Bearer $token";

    // Fields
    request.fields['event[title]'] = title;
    request.fields['event[description]'] = description;
    request.fields['event[start_time]'] = startTime.toIso8601String();
    if (endTime != null) request.fields['event[end_time]'] = endTime.toIso8601String();
    if (location != null) request.fields['event[location]'] = location;

    // Cover image
    if (coverImage != null) {
      request.files.add(await http.MultipartFile.fromPath("event[cover_image]", coverImage.path));
    }

    // Additional files
    if (files != null) {
      for (final f in files) {
        request.files.add(await http.MultipartFile.fromPath("event[files][]", f.path));
      }
    }

    // Send
    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 201 || res.statusCode == 200) {
      return JsonApiParser.parseEvent(body);
    } else {
      print("❌ Create event failed: ${res.statusCode} → $body");
      throw Exception("Failed to create event");
    }
  }
}