class Mission {
  final String key;
  final String title;
  final String description;
  final String category;
  final int rewardXp;
  final String? rewardBadge;
  final List<String> checklist;

  const Mission({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.rewardXp,
    this.rewardBadge,
    this.checklist = const [],
  });

  factory Mission.fromJson(Map<String, dynamic> json) {
    final metadata = (json['metadata'] ??
            json['mission_metadata'] ??
            json['meta']) as Map<String, dynamic>? ??
        const {};
    final checklist = (metadata['checklist'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];
    final reward = json['reward_xp'];
    return Mission(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      rewardXp: reward is num
          ? reward.toInt()
          : int.tryParse(reward?.toString() ?? '') ?? 0,
      rewardBadge: json['reward_badge']?.toString(),
      checklist: checklist,
    );
  }
}

class UserMission {
  final String id;
  final String status;
  final int progress;
  final int targetValue;
  final DateTime? expiresAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final double progressRatio;
  final Mission mission;

  const UserMission({
    required this.id,
    required this.status,
    required this.progress,
    required this.targetValue,
    required this.expiresAt,
    required this.completedAt,
    required this.createdAt,
    required this.progressRatio,
    required this.mission,
  });

  factory UserMission.fromJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;
    final progressValue = attrs['progress'];
    final targetValue = attrs['target_value'];
    final progress = progressValue is num
        ? progressValue.toInt()
        : int.tryParse(progressValue?.toString() ?? '') ?? 0;
    final target = targetValue is num
        ? targetValue.toInt()
        : int.tryParse(targetValue?.toString() ?? '') ?? 0;
    final ratioValue = attrs['progress_ratio'];
    final ratio = ratioValue is num
        ? ratioValue.toDouble()
        : double.tryParse(ratioValue?.toString() ?? '') ??
            (target > 0 ? progress / target : 0);

    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value.toString());

    return UserMission(
      id: (json['id'] ?? '').toString(),
      status: (attrs['status'] ?? 'pending').toString(),
      progress: progress,
      targetValue: target,
      expiresAt: parseDate(attrs['expires_at']),
      completedAt: parseDate(attrs['completed_at']),
      createdAt: parseDate(attrs['created_at']),
      progressRatio: ratio.clamp(0.0, 1.0).toDouble(),
      mission: Mission.fromJson(
        (attrs['mission'] as Map<String, dynamic>? ?? const {}),
      ),
    );
  }
}
