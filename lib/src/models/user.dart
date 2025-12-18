class User {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? tag;
  final String? avatarUrl;
  final int xp;
  final List<String> badges;

  User({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.username,
    this.tag,
    this.avatarUrl,
    this.xp = 0,
    this.badges = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;
    final cosmeticUnlocks = attrs['cosmetic_unlocks'] as Map<String, dynamic>?;
    final badgesList = (cosmeticUnlocks?['badges'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final xpValue = attrs['xp'];
    return User(
      id: (json['id'] ?? attrs['id'] ?? '').toString(),
      email: (attrs['email'] ?? '').toString(),
      firstName: attrs['first_name']?.toString(),
      lastName: attrs['last_name']?.toString(),
      username: attrs['username']?.toString(),
      tag: attrs['tag']?.toString(),
      avatarUrl: attrs['avatar_url']?.toString(),
      xp: xpValue is num
          ? xpValue.toInt()
          : int.tryParse(xpValue?.toString() ?? '') ?? 0,
      badges: badgesList,
    );
  }

  @override
  String toString() =>
      'User(id:$id, email:$email, username:$username, avatarUrl:$avatarUrl, xp:$xp)';
}
