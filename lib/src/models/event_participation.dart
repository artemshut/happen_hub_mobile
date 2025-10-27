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
    } else {
      print(' No relationships.user.data found');
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

  factory EventParticipation.fromAttributes(Map<String, dynamic> attrs) {
    print('EventParticipation.fromAttributes called -> attrs keys=${attrs.keys}');
    final userId = attrs['id']?.toString();
    final status = (attrs['status'] ?? attrs['rsvp_status'] ?? 'pending')
        .toString()
        .toLowerCase()
        .trim();
    print(' Derived rsvp_status from attributes: "$status" for userId=$userId');

    final user = User(
      id: userId ?? '',
      email: (attrs['email'] ?? '').toString(),
      firstName: attrs['first_name']?.toString(),
      lastName: attrs['last_name']?.toString(),
      username: attrs['username']?.toString(),
      tag: attrs['tag']?.toString(),
      avatarUrl: attrs['avatar_url']?.toString(),
    );

    return EventParticipation(
      id: (attrs['participation_id'] ?? userId ?? 'embedded').toString(),
      rsvpStatus: status.isEmpty ? 'pending' : status,
      user: userId == null && (attrs['email'] ?? '').toString().isEmpty
          ? null
          : user,
      userId: userId,
    );
  }
}
