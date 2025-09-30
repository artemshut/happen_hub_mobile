// lib/models/event.dart
import 'user.dart';
import 'event_category.dart';
import 'comment.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final User? user; // owner
  final EventCategory? category;

  // Extra fields
  final List<User>? participants;
  final double? latitude;
  final double? longitude;
  final List<Comment>? comments;
  final String? coverImageUrl;   // ✅ cover image
  final List<EventFile>? files;  // ✅ event files (tickets, etc.)

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    this.endTime,
    this.location,
    this.user,
    this.category,
    this.participants,
    this.comments,
    this.latitude,
    this.longitude,
    this.coverImageUrl,
    this.files,
  });

  factory Event.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? included,
  }) {
    User? u;
    EventCategory? cat;
    List<User> participants = [];
    List<Comment> comments = [];

    // Owner
    if (json['relationships']?['user']?['data'] != null && included != null) {
      final ref = json['relationships']['user']['data'];
      final inc = included[ref['type']]?[ref['id']];
      if (inc != null) u = User.fromJson(inc['attributes']);
    }

    // Category
    if (json['relationships']?['event_category']?['data'] != null &&
        included != null) {
      final ref = json['relationships']['event_category']['data'];
      final inc = included[ref['type']]?[ref['id']];
      if (inc != null) cat = EventCategory.fromJson(inc['attributes']);
    }

    // Participants
    if (json['relationships']?['participants']?['data'] != null &&
        included != null) {
      final refs = json['relationships']['participants']['data'] as List;
      for (var ref in refs) {
        final inc = included[ref['type']]?[ref['id']];
        if (inc != null) participants.add(User.fromJson(inc['attributes']));
      }
    }

    // Comments
    if (json['relationships']?['comments']?['data'] != null &&
        included != null) {
      final refs = json['relationships']['comments']['data'] as List;
      for (var ref in refs) {
        final inc = included[ref['type']]?[ref['id']];
        if (inc != null) {
          comments.add(Comment.fromJson(inc));
        }
      }
    }

    // Cover image
    final coverImageUrl = json['attributes']?['cover_image_url'];

    // Files (parse list of EventFile)
    final rawFiles = json['attributes']?['files'] as List<dynamic>?;
    final files =
        rawFiles?.map((f) => EventFile.fromJson(f as Map<String, dynamic>)).toList();

    // ✅ Handle description safely
    final descRaw = json['attributes']?['description'];
    final description = (descRaw is String)
        ? descRaw
        : (descRaw is Map<String, dynamic> ? descRaw['body'] ?? '' : '');

    return Event(
      id: json['id'].toString(),
      title: json['attributes']['title'] ?? '',
      description: description,
      startTime: DateTime.parse(json['attributes']['start_time']),
      endTime: json['attributes']['end_time'] != null
          ? DateTime.tryParse(json['attributes']['end_time'])
          : null,
      location: json['attributes']['location'],
      user: u,
      category: cat,
      participants: participants,
      comments: comments,
      coverImageUrl: coverImageUrl,
      files: files,
      latitude: json['attributes']['latitude'] != null
          ? (json['attributes']['latitude'] as num).toDouble()
          : null,
      longitude: json['attributes']['longitude'] != null
          ? (json['attributes']['longitude'] as num).toDouble()
          : null,
    );
  }
}

/// ✅ Strongly typed file model
class EventFile {
  final String url;
  final String filename;
  final String contentType;
  final String mimeType;

  EventFile({
    required this.url,
    required this.filename,
    required this.contentType,
    required this.mimeType,
  });

  factory EventFile.fromJson(Map<String, dynamic> json) {
    return EventFile(
      mimeType: json['mime_type'] ?? 'application/octet-stream',
      url: json['url'] ?? '',
      filename: json['filename'] ?? '',
      contentType: json['content_type'] ?? '',
    );
  }

  bool get isImage => contentType.startsWith("image/");
  bool get isPdf => contentType == "application/pdf";
}