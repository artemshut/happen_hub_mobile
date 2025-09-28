class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? tag;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.username,
    this.tag,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] ?? json;
    return User(
      id: json['id']?.toString() ?? '',
      email: attrs['email'] ?? '',
      firstName: attrs['first_name'],
      lastName: attrs['last_name'],
      username: attrs['username'],
      tag: attrs['tag'],
      avatarUrl: attrs['avatar_url'],
    );
  }
}