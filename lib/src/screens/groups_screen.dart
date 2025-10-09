import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/group.dart';
import '../models/user.dart';
import '../providers/user_provider.dart';
import '../repositories/group_repository.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupRepository _repository = GroupRepository();
  late Future<List<Group>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _groupsFuture = _repository.fetchGroups(context);
  }

  Future<void> _refresh() async {
    final future = _repository.fetchGroups(context);
    setState(() => _groupsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = Provider.of<UserProvider>(context).user;
    final currentUserId = currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Groups"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: FutureBuilder<List<Group>>(
        future: _groupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 32),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load groups',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final groups = snapshot.data ?? [];
          final createdByMe = currentUserId == null
              ? <Group>[]
              : groups.where((g) => g.creatorId == currentUserId).toList();
          final memberGroups = currentUserId == null
              ? groups.length
              : groups.length - createdByMe.length;

          if (groups.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(32),
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.groups_rounded, size: 48, color: cs.primary),
                  const SizedBox(height: 16),
                  Text(
                    "You're not part of any groups yet",
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create a group and invite friends to make planning easier.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant.withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            );
          }

          final items = <Widget>[
            _SectionHeader(
              title: "Groups",
              highlight: "${groups.length} total",
              icon: Icons.groups_rounded,
              color: cs.primary,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 12),
            _SummaryHeader(
              totalGroups: groups.length,
              createdByMe: createdByMe.length,
              memberGroups: memberGroups,
            ),
            const SizedBox(height: 8),
            ...groups.map((group) {
              final isOwner =
                  currentUserId != null && group.creatorId == currentUserId;
              return _GroupCard(
                group: group,
                isOwner: isOwner,
                onTap: () => _showGroupDetails(context, group, currentUser),
              );
            }),
            const SizedBox(height: 32),
          ];

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              children: items,
            ),
          );
        },
      ),
    );
  }

  void _showGroupDetails(BuildContext context, Group group, User? currentUser) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final members = group.members;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.name,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if ((group.description ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  group.description!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withOpacity(0.9),
                      ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                "Members (${members.length})",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...members.map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _AvatarCircle(user: member),
                  title: Text(member.username ?? member.email),
                  subtitle: member.email != null && member.email.isNotEmpty
                      ? Text(member.email)
                      : null,
                  trailing: currentUser != null &&
                          member.id == currentUser.id &&
                          group.creatorId == member.id
                      ? const Chip(
                          label: Text(
                            "Owner",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String highlight;
  final IconData icon;
  final Color color;
  final Future<void> Function() onRefresh;

  const _SectionHeader({
    required this.title,
    required this.highlight,
    required this.icon,
    required this.color,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  highlight,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: "Refresh",
          icon: Icon(Icons.refresh_rounded, color: color),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  final int totalGroups;
  final int createdByMe;
  final int memberGroups;

  const _SummaryHeader({
    required this.totalGroups,
    required this.createdByMe,
    required this.memberGroups,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metrics = [
      _SummaryMetric(
        icon: Icons.groups_rounded,
        label: "Total",
        value: totalGroups.toString(),
        color: cs.primary,
      ),
      _SummaryMetric(
        icon: Icons.star_rounded,
        label: "Created",
        value: createdByMe.toString(),
        color: cs.secondary,
      ),
      _SummaryMetric(
        icon: Icons.handshake_rounded,
        label: "Member",
        value: memberGroups.toString(),
        color: cs.tertiary ?? cs.primary,
      ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: metrics
            .map(
              (metric) => Expanded(
                child: _SummaryPill(metric: metric),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SummaryMetric {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _SummaryPill extends StatelessWidget {
  final _SummaryMetric metric;

  const _SummaryPill({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: metric.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: metric.color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(metric.icon, size: 16, color: metric.color),
              const SizedBox(width: 6),
              Text(
                metric.label,
                style: TextStyle(
                  color: metric.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final bool isOwner;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = group.name.isNotEmpty ? group.name[0].toUpperCase() : "?";

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: cs.primary.withOpacity(0.15),
                child: Text(
                  primary,
                  style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isOwner)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: cs.secondary.withOpacity(0.4)),
                            ),
                            child: Text(
                              "Owner",
                              style: TextStyle(
                                  color: cs.secondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    if ((group.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        group.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          "${group.memberCount} member${group.memberCount == 1 ? '' : 's'}",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _MemberAvatars(members: group.members),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  final List<User> members;

  const _MemberAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final display = members.take(5).toList();
    final remaining = members.length - display.length;

    return SizedBox(
      height: 40,
      child: Stack(
        children: [
          for (int i = 0; i < display.length; i++)
            Positioned(
              left: i * 26,
              child: _AvatarCircle(user: display[i]),
            ),
          if (remaining > 0)
            Positioned(
              left: display.length * 26,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: cs.primary,
                child: Text(
                  "+$remaining",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final User user;

  const _AvatarCircle({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial = (user.username ?? user.email).trim().isNotEmpty
        ? (user.username ?? user.email).trim()[0].toUpperCase()
        : "?";
    if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: NetworkImage(user.avatarUrl!),
      );
    }
    return CircleAvatar(
      radius: 18,
      backgroundColor:
          Theme.of(context).colorScheme.primary.withOpacity(0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
