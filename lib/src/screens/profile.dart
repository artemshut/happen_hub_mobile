import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user.dart';
import '../models/mission.dart';
import '../repositories/mission_repository.dart';
import 'plans_screen.dart';
import 'login.dart';
import '../services/auth_service.dart';
import '../providers/theme_provider.dart';
import '../providers/user_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final AuthService _authService = AuthService();
  final MissionRepository _missionRepository = MissionRepository();
  User? _user;
  List<UserMission> _missions = [];
  bool _missionsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMissions();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _user = user;
    });
  }

  Future<void> _loadMissions() async {
    try {
      final missions = await _missionRepository.fetchMissions();
      if (!mounted) return;
      setState(() {
        _missions = missions;
        _missionsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _missionsLoading = false;
      });
    }
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadUser(),
      _loadMissions(),
    ]);
  }

  Future<void> _signOut(BuildContext context) async {
    await _authService.logout(); // ✅ clear "token" & "refresh_token"
    ref.read(userProvider.notifier).clearUser();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    if (_user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user!;
    final handle =
        (user.username?.trim().isNotEmpty ?? false) ? user.username!.trim() : user.email;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ProfileHeader(
              user: user,
              colorScheme: cs,
              onSignOut: () => _signOut(context),
            ),
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "@$handle",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  Text(
                    user.tag ?? "",
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (user.email.isNotEmpty)
                    Text(
                      user.email,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShareProfileScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(Icons.share),
                label: const Text("Share Profile"),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _XpCard(user: user),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildMissionsSection(context, cs),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _ThemeToggleCard(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlansScreen()),
                  );
                },
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Plans & Pricing'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsSection(BuildContext context, ColorScheme cs) {
    if (_missionsLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: cs.surfaceVariant.withOpacity(0.4),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_missions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: Icons.flag_outlined,
            title: "Missions & boosts",
            subtitle: "Check back soon for new goals.",
          ),
          const SizedBox(height: 8),
          Text(
            "No active missions right now.",
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          icon: Icons.flag_outlined,
          title: "Missions & boosts",
          subtitle: "Unlock badges and XP by staying on track.",
        ),
        const SizedBox(height: 12),
        Column(
          children: _missions.map((m) => _MissionCard(userMission: m)).toList(),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _SectionHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _SectionHeading({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final UserMission userMission;

  const _MissionCard({required this.userMission});

  Color _statusColor(ColorScheme cs) {
    switch (userMission.status) {
      case 'completed':
        return cs.primary;
      case 'expired':
        return cs.error;
      case 'in_progress':
        return cs.secondary;
      default:
        return cs.outline;
    }
  }

  String _statusLabel() {
    switch (userMission.status) {
      case 'completed':
        return "Rewards granted";
      case 'expired':
        return "Mission expired";
      case 'in_progress':
        return "${userMission.progress}/${userMission.targetValue} steps";
      default:
        return "Break the streak? Start now.";
    }
  }

  String? _expiresLabel() {
    if (userMission.expiresAt == null ||
        userMission.status == 'completed' ||
        userMission.status == 'expired') {
      return null;
    }
    final now = DateTime.now();
    final diff = userMission.expiresAt!.difference(now);
    if (diff.inSeconds <= 0) return "Expires soon";
    if (diff.inDays > 0) return "Expires in ${diff.inDays}d";
    if (diff.inHours > 0) return "Expires in ${diff.inHours}h";
    return "Expires in ${diff.inMinutes}m";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = userMission.progressRatio.clamp(0, 1).toDouble();
    final statusColor = _statusColor(cs);
    final expires = _expiresLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withOpacity(0.18)),
        gradient: LinearGradient(
          colors: [
            cs.surfaceVariant.withOpacity(0.35),
            cs.surface.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  userMission.mission.category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const Spacer(),
              if (expires != null)
                Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      expires,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            userMission.mission.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            userMission.mission.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: cs.surfaceVariant.withOpacity(0.35),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                _statusLabel(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.bolt, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    "+${userMission.mission.rewardXp} XP",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
          if (userMission.mission.rewardBadge != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 16, color: cs.secondary),
                const SizedBox(width: 4),
                Text(
                  userMission.mission.rewardBadge!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.secondary,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User user;
  final ColorScheme colorScheme;
  final VoidCallback onSignOut;

  const _ProfileHeader({
    required this.user,
    required this.colorScheme,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: -50,
            child: CircleAvatar(
              radius: 55,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: user.avatarUrl == null
                    ? Text(
                        ((user.firstName ?? user.username ?? "U")
                                .trim()
                                .isNotEmpty
                            ? (user.firstName ?? user.username ?? "U")
                                .trim()[0]
                                .toUpperCase()
                            : "U"),
                        style: const TextStyle(fontSize: 28),
                      )
                    : null,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: onSignOut,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final mode = themeState.value ?? ThemeMode.dark;
    final isDark = mode == ThemeMode.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: cs.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDark ? "Dark mode" : "Light mode",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Switch between night and day vibes",
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Switch(
            value: isDark,
            activeColor: cs.primary,
            onChanged: themeState.isLoading
                ? null
                : (_) =>
                    ref.read(themeControllerProvider.notifier).toggleTheme(),
          ),
        ],
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  final User user;

  const _XpCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
        color: cs.surfaceVariant.withOpacity(0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                "XP Boost",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Text(
                "${user.xp} XP",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (user.badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.badges
                  .map(
                    (badge) => Chip(
                      label: Text(badge),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Complete missions to collect badges.",
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class ShareProfileScreen extends StatelessWidget {
  final User user;

  const ShareProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profileUrl = "https://happenhub.co/u/${user.username}";

    return Scaffold(
      appBar: AppBar(title: const Text("Share Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null
                  ? Text(user.firstName?[0] ?? "U")
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              "@${user.username}",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            Text(
              "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            QrImageView(
              data: profileUrl,
              version: QrVersions.auto,
              size: 200.0,
            ),
            const SizedBox(height: 12),
            Text(
              profileUrl,
              style: TextStyle(
                color: cs.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
