import 'user.dart';

class EventParticipation {
  final String id;
  final String rsvpStatus;
  final User? user;

  EventParticipation({
    required this.id,
    required this.rsvpStatus,
    required this.user,
  });

  factory EventParticipation.fromJson(
    Map<String, dynamic> json, {
    required Map<String, Map<String, dynamic>> included,
  }) {
    final attrs = (json['attributes'] ?? const {}) as Map<String, dynamic>;
    User? u;

    // resolve linked user
    final relUser = json['relationships']?['user']?['data'];
    if (relUser != null) {
      final String type = (relUser['type'] ?? 'users').toString(); // "users"
      final String id = relUser['id'].toString();
      final incUser = included[type]?[id];
      if (incUser != null) {
        u = User.fromJson({
          'id': incUser['id'],
          'attributes': incUser['attributes'],
        });
      }
    }

    return EventParticipation(
      id: json['id'].toString(),
      rsvpStatus: (attrs['rsvp_status'] ?? 'pending').toString(),
      user: u,
    );
  }
}