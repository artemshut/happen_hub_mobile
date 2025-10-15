import 'user.dart';

class EventParticipation {
  final String id;
  final String rsvpStatus;
  final User? user;
  final String? userId;

  EventParticipation({
    required this.id,
    required this.rsvpStatus,
    required this.user,
    this.userId,
  });

  factory EventParticipation.fromJson(
    Map<String, dynamic> json, {
    required Map<String, Map<String, dynamic>> included,
  }) {
    final attrs = (json['attributes'] ?? const {}) as Map<String, dynamic>;
    User? u;

    // resolve linked user
    final relUser = json['relationships']?['user']?['data'];
    String? resolvedUserId;
    if (relUser != null) {
      final String type = (relUser['type'] ?? 'users').toString();
      final String id = relUser['id'].toString();
      resolvedUserId = id;
      final incUser = included[type]?[id];
      if (incUser != null) {
        u = User.fromJson({
          'id': incUser['id'],
          'attributes': incUser['attributes'],
        });
      }
    }

    final status = (attrs['rsvp_status'] ?? 'pending')
        .toString()
        .toLowerCase()
        .trim();

    return EventParticipation(
      id: json['id'].toString(),
      rsvpStatus: status.isEmpty ? 'pending' : status,
      user: u,
      userId: resolvedUserId,
    );
  }
}
