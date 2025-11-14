class Plan {
  final int id;
  final String key;
  final String name;
  final String? tagline;
  final int monthlyPriceCents;
  final int annualPriceCents;
  final int? maxActiveEvents;
  final bool highlighted;
  final int priority;
  final List<String> features;
  final bool unlimitedEvents;
  final bool isCurrentPlan;
  final String? displayPrice; // e.g., "Free" or "$12/mo"

  const Plan({
    required this.id,
    required this.key,
    required this.name,
    required this.tagline,
    required this.monthlyPriceCents,
    required this.annualPriceCents,
    required this.maxActiveEvents,
    required this.highlighted,
    required this.priority,
    required this.features,
    required this.unlimitedEvents,
    required this.isCurrentPlan,
    required this.displayPrice,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    // Accept both JSON:API shape (data[i].attributes...) and flat maps
    final attrs = (json['attributes'] ?? json) as Map<String, dynamic>;
    return Plan(
      id: int.tryParse((json['id'] ?? attrs['id'] ?? '0').toString()) ?? 0,
      key: (attrs['key'] ?? '').toString(),
      name: (attrs['name'] ?? '').toString(),
      tagline: attrs['tagline']?.toString(),
      monthlyPriceCents: int.tryParse((attrs['monthly_price_cents'] ?? 0).toString()) ?? 0,
      annualPriceCents: int.tryParse((attrs['annual_price_cents'] ?? 0).toString()) ?? 0,
      maxActiveEvents: attrs['max_active_events'] == null
          ? null
          : int.tryParse(attrs['max_active_events'].toString()),
      highlighted: (attrs['highlighted'] ?? false) == true,
      priority: int.tryParse((attrs['priority'] ?? 0).toString()) ?? 0,
      features: List<String>.from((attrs['features'] as List<dynamic>? ?? const [])
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)),
      unlimitedEvents: (attrs['unlimited_events'] ?? attrs['unlimitedEvents'] ?? false) == true,
      isCurrentPlan: (attrs['is_current_plan'] ?? attrs['isCurrentPlan'] ?? false) == true,
      displayPrice: attrs['display_price']?.toString(),
    );
  }

  double get pricePerMonth => monthlyPriceCents / 100.0;
}

