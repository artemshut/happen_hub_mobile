class EventCategory {
  final String id;
  final String name;
  final String? emoji;
  final String? description;

  EventCategory({
    required this.id,
    required this.name,
    this.emoji,
    this.description,
  });

  factory EventCategory.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] ?? json;
    return EventCategory(
      id: json['id']?.toString() ?? '',
      name: attrs['name'] ?? '',
      emoji: attrs['emoji'],
      description: attrs['description'],
    );
  }
}