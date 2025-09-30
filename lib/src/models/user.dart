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
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;
    return User(
      id: (json['id'] ?? attrs['id'] ?? '').toString(),
      email: (attrs['email'] ?? '').toString(),
      firstName: attrs['first_name']?.toString(),
      lastName: attrs['last_name']?.toString(),
      username: attrs['username']?.toString(),
      tag: attrs['tag']?.toString(),
      avatarUrl: attrs['avatar_url']?.toString(),
    );
  }

  @override
  String toString() =>
      'User(id:$id, email:$email, username:$username, avatarUrl:$avatarUrl)';
}