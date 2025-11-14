import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/plan.dart';
import '../repositories/plan_repository.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final PlanRepository _repo = PlanRepository();
  late Future<List<Plan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchPlans();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Plans & Pricing')),
      body: FutureBuilder<List<Plan>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load plans.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final plans = snap.data ?? const [];
          if (plans.isEmpty) {
            return const Center(child: Text('No plans available'));
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _PlanCard(plan: plans[i]),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final uri = Uri.parse('https://happenhub.co/pricing');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Manage subscription on web'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.primary,
              side: BorderSide(color: cs.primary.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Plan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCurrent = plan.isCurrentPlan;
    final titleStyle = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: plan.highlighted
            ? cs.primary.withOpacity(0.08)
            : Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: plan.highlighted
              ? cs.primary.withOpacity(0.35)
              : cs.outline.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: titleStyle),
                    if (plan.tagline != null && plan.tagline!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          plan.tagline!,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.primary.withOpacity(0.35)),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                plan.displayPrice ??
                    (plan.monthlyPriceCents == 0
                        ? 'Free'
                        : "\$${plan.pricePerMonth.toStringAsFixed(0)}/mo"),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              if (!plan.unlimitedEvents && plan.maxActiveEvents != null)
                Text(
                  '• up to ${plan.maxActiveEvents} active events',
                  style: TextStyle(color: cs.onSurfaceVariant),
                )
              else
                Text(
                  '• unlimited events',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (plan.features.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: plan.features.take(6).map((f) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle,
                          size: 18, color: cs.primary.withOpacity(0.9)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isCurrent
                      ? null
                      : () async {
                          final uri = Uri.parse('https://happenhub.co/pricing');
                          if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                  child: Text(isCurrent ? 'Current plan' : 'Upgrade'),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
