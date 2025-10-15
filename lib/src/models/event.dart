import 'user.dart';
import 'event_category.dart';
import 'comment.dart';
import 'event_participation.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final String? location;
  final User? user; // owner
  final EventCategory? category;
  final List<EventParticipation>? participations;
  final double? latitude;
  final double? longitude;
  final List<Comment>? comments;
  final String? coverImageUrl;
  String? visibility; // "public" or "friends" or "private"
  final List<EventFile>? files;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.startTime,
    this.endTime,
    this.location,
    this.user,
    this.category,
    this.participations,
    this.comments,
    this.latitude,
    this.longitude,
    this.visibility,
    this.coverImageUrl,
    this.files,
  });

  factory Event.fromJson(
    Map<String, dynamic> json, {
    Map<String, Map<String, dynamic>>? included,
  }) {
    final idx = included ?? {};

    User? owner;
    EventCategory? cat;
    final participations = <EventParticipation>[];
    final comments = <Comment>[];

    // --- Owner ---
    final ownerRef = json['relationships']?['user']?['data'];
    if (ownerRef != null) {
      final inc = idx[ownerRef['type']]?[ownerRef['id']];
      if (inc != null) {
        owner = User.fromJson({'id': inc['id'], 'attributes': inc['attributes']});
      }
    }

    // --- Category ---
    final catRef = json['relationships']?['event_category']?['data'];
    if (catRef != null) {
      final inc = idx[catRef['type']]?[catRef['id']];
      if (inc != null) {
        cat = EventCategory.fromJson(inc['attributes']);
      }
    }

    // --- Participations ---
    final partRefs = (json['relationships']?['event_participations']?['data'] as List?) ?? const [];
    for (final ref in partRefs) {
      final inc = idx[ref['type']]?[ref['id']];
      if (inc != null) {
        final p = EventParticipation.fromJson(inc, included: idx);
        participations.add(p);
      }
    }

    // --- Comments ---
    final commentRefs = (json['relationships']?['comments']?['data'] as List?) ?? const [];
    for (final ref in commentRefs) {
      final inc = idx[ref['type']]?[ref['id']];
      if (inc != null) {
        comments.add(Comment.fromJson(inc, included: idx));
      }
    }

    final attrs = (json['attributes'] ?? const {}) as Map<String, dynamic>;

    final rawFiles = attrs['files'] as List<dynamic>?;
    final files = rawFiles?.map((f) => EventFile.fromJson(f as Map<String, dynamic>)).toList();

    final descRaw = attrs['description'];
    final description = (descRaw is String)
        ? descRaw
        : (descRaw is Map<String, dynamic> ? (descRaw['body'] ?? '') : '');

    final embeddedParticipants = (attrs['participants'] as List<dynamic>? ?? const [])
        .cast<dynamic>();
    if (embeddedParticipants.isNotEmpty) {
      for (final entry in embeddedParticipants) {
        final map = (entry as Map).cast<String, dynamic>();
        final userId = map['id']?.toString();
        final exists = participations.any(
          (p) => (p.userId ?? p.user?.id) == userId,
        );
        if (!exists) {
          participations.add(EventParticipation.fromAttributes(map));
        }
      }
    }

    return Event(
      id: json['id'].toString(),
      title: (attrs['title'] ?? '').toString(),
      description: description,
      startTime: DateTime.parse(attrs['start_time']),
      endTime: attrs['end_time'] != null ? DateTime.tryParse(attrs['end_time']) : null,
      location: attrs['location']?.toString(),
      user: owner,
      category: cat,
      participations: participations,
      comments: comments,
      coverImageUrl: attrs['cover_image_url']?.toString(),
      files: files,
      visibility: attrs['visibility']?.toString(),
      latitude: attrs['latitude'] != null ? (attrs['latitude'] as num).toDouble() : null,
      longitude: attrs['longitude'] != null ? (attrs['longitude'] as num).toDouble() : null,
    );
  }
}

class EventFile {
  final String url;
  final String filename;
  final String contentType;
  final String mimeType;
  final String signedId;

  EventFile({
    required this.url,
    required this.filename,
    required this.contentType,
    required this.mimeType,
    required this.signedId,
  });

  factory EventFile.fromJson(Map<String, dynamic> json) {
    return EventFile(
      mimeType: (json['mime_type'] ?? 'application/octet-stream').toString(),
      url: (json['url'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      contentType: (json['content_type'] ?? '').toString(),
      signedId: json['signed_id'].toString(),
    );
  }

  bool get isImage => contentType.startsWith('image/');
  bool get isPdf => contentType == 'application/pdf';
}
