import 'dart:io';
import 'dart:convert';
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

    final upcomingRes = await _client.get("/events", token: token);
    if (upcomingRes.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    }
    if (upcomingRes.statusCode != 200) {
      throw Exception("Failed to load events (${upcomingRes.statusCode})");
    }

    final Map<String, Event> eventsById = {};
    final upcomingEvents = JsonApiParser.parseEvents(upcomingRes.body);
    for (final event in upcomingEvents) {
      eventsById[event.id] = event;
    }

    final pastRes = await _client.get("/events?past=true", token: token);
    if (pastRes.statusCode == 401) {
      throw Exception("Unauthorized. Please log in again.");
    }
    if (pastRes.statusCode != 200) {
      throw Exception("Failed to load past events (${pastRes.statusCode})");
    }

    final pastEvents = JsonApiParser.parseEvents(pastRes.body);
    for (final event in pastEvents) {
      eventsById[event.id] = event;
    }

    return eventsById.values.toList();
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

  Future<void> updateRsvp(
    BuildContext context,
    String eventId,
    String status,
  ) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final res = await _client.post("/events/$eventId/rsvp", {
      "status": status,
    }, token: token);
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
    String? visibility,
    String? categoryId,
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
    if (endTime != null) {
      request.fields['event[end_time]'] = endTime.toIso8601String();
    }
    if (location != null) request.fields['event[location]'] = location;
    if (latitude != null) {
      request.fields['event[latitude]'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['event[longitude]'] = longitude.toString();
    }
    if (visibility != null) {
      request.fields['event[visibility]'] = visibility;
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      request.fields['event[event_category_id]'] = categoryId;
    }

    // Cover image
    if (coverImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "event[cover_image]",
          coverImage.path,
        ),
      );
    }

    // Additional files
    if (files != null) {
      for (final f in files) {
        request.files.add(
          await http.MultipartFile.fromPath("event[files][]", f.path),
        );
      }
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 201 || res.statusCode == 200) {
      return JsonApiParser.parseEvent(body);
    } else {
      print("❌ Create event failed: ${res.statusCode} → $body");
      throw Exception("Failed to create event");
    }
  }

  /// ✅ Update event (with file removal + new uploads)
  Future<Event> updateEvent({
    required String eventId,
    required String title,
    required String description,
    required DateTime startTime,
    DateTime? endTime,
    String? visibility,
    String? location,
    double? latitude,
    double? longitude,
    String? categoryId,
    File? coverImage,
    List<File>? files,
    List<String>? removedFiles, // signed_id from BE
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final uri = Uri.parse("${_client.baseUrl}/events/$eventId");
    final request = http.MultipartRequest("PUT", uri);

    // Auth
    request.headers['Authorization'] = "Bearer $token";

    // Fields
    request.fields['event[title]'] = title;
    request.fields['event[description]'] = description;
    request.fields['event[start_time]'] = startTime.toIso8601String();
    if (endTime != null) {
      request.fields['event[end_time]'] = endTime.toIso8601String();
    }
    if (location != null) request.fields['event[location]'] = location;
    if (latitude != null) {
      request.fields['event[latitude]'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['event[longitude]'] = longitude.toString();
    }
    if (visibility != null) {
      request.fields['event[visibility]'] = visibility;
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      request.fields['event[event_category_id]'] = categoryId;
    }

    // Cover image (optional new one)
    if (coverImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          "event[cover_image]",
          coverImage.path,
        ),
      );
    }

    // Additional new files
    if (files != null) {
      for (final f in files) {
        request.files.add(
          await http.MultipartFile.fromPath("event[files][]", f.path),
        );
      }
    }

    // Removed files (signed_ids)
    if (removedFiles != null && removedFiles.isNotEmpty) {
      for (final id in removedFiles) {
        request.fields['event[removed_files][]'] = id;
      }
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();

    if (res.statusCode == 200) {
      return JsonApiParser.parseEvent(body);
    } else {
      print("❌ Update event failed: ${res.statusCode} → $body");
      throw Exception("Failed to update event");
    }
  }

  Future<Event> uploadEventFiles({
    required String eventId,
    required List<File> files,
  }) async {
    if (files.isEmpty) {
      throw Exception("No files selected");
    }

    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final uri = Uri.parse("${_client.baseUrl}/events/$eventId/upload_files");
    final request = http.MultipartRequest("POST", uri);
    request.headers['Authorization'] = "Bearer $token";

    for (final file in files) {
      request.files.add(
        await http.MultipartFile.fromPath("event[files][]", file.path),
      );
    }

    final res = await request.send();
    final body = await res.stream.bytesToString();
    if (res.statusCode == 200 || res.statusCode == 201) {
      return JsonApiParser.parseEvent(body);
    }

    print("❌ Upload event files failed: ${res.statusCode} → $body");
    throw Exception("Failed to upload files (${res.statusCode})");
  }

  Future<Event> deleteEventFile({
    required String eventId,
    required String signedId,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception("No token found. Please log in.");

    final res = await _client.patch("/events/$eventId", {
      "event": {
        "removed_files": [signedId],
      },
    }, token: token);

    if (res.statusCode == 200) {
      return JsonApiParser.parseEvent(res.body);
    }

    print("❌ Delete file failed: ${res.statusCode} → ${res.body}");
    throw Exception("Failed to delete file (${res.statusCode})");
  }
}
