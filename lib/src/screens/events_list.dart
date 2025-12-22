// lib/screens/events_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/event_repository.dart';
import '../models/event.dart';
import '../providers/user_provider.dart';
import 'event.dart';
import 'create_event.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen>
    with AutomaticKeepAliveClientMixin {
  final EventRepository _repo = EventRepository();
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _repo.fetchEvents(context);
  }

  Future<void> _refreshEvents() async {
    final future = _repo.fetchEvents(context);
    setState(() {
      _eventsFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(userProvider);
    final currentUserId = currentUser?.id ?? "";

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 24,
        title: Text(
          "All Events",
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.primary.withOpacity(0.85),
                const Color(0xFF14121C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newEvent = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (newEvent != null && mounted) {
            await _refreshEvents();
          }
        },
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Create Event"),
      ),
      body: FutureBuilder<List<Event>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No events found."));
          }

          final events = snapshot.data!;
          final now = DateTime.now();

          final upcoming = events
              .where((e) => !_isEventPast(e, now))
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
          final past = events
              .where((e) => _isEventPast(e, now))
              .toList()
            ..sort((a, b) => b.startTime.compareTo(a.startTime));

          return RefreshIndicator(
            color: cs.primary,
            onRefresh: _refreshEvents,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildSectionHeader(
                  context,
                  title: "Upcoming & ongoing",
                  highlight: "${upcoming.length} events",
                  icon: Icons.upcoming_rounded,
                  color: cs.primary,
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  _buildEmptySection(
                    context,
                    title: "No upcoming events yet",
                    subtitle:
                        "Create something new or check out past highlights below.",
                    icon: Icons.calendar_today_rounded,
                  )
                else
                  ...upcoming.map(
                    (event) => _buildEventCard(
                      event,
                      currentUserId: currentUserId,
                      isPast: false,
                      isOngoing: _isEventOngoing(event, now),
                    ),
                  ),
                const SizedBox(height: 32),
                _buildSectionHeader(
                  context,
                  title: "Past highlights",
                  highlight: "${past.length} events",
                  icon: Icons.history_rounded,
                  color: cs.secondary,
                ),
                const SizedBox(height: 12),
                if (past.isEmpty)
                  _buildEmptySection(
                    context,
                    title: "No past events yet",
                    subtitle:
                        "Once events wrap up they’ll appear here for easy reference.",
                    icon: Icons.inbox_outlined,
                  )
                else
                  ...past.map(
                    (event) => _buildEventCard(
                      event,
                      currentUserId: currentUserId,
                      isPast: true,
                      isOngoing: false,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isEventPast(Event e, DateTime comparison) {
    final end = e.endTime ?? e.startTime;
    return end.isBefore(comparison);
  }

  bool _isEventOngoing(Event e, DateTime comparison) {
    final end = e.endTime ?? e.startTime;
    final start = e.startTime;
    return !start.isAfter(comparison) && !end.isBefore(comparison);
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String highlight,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
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
        ],
      ),
    );
  }

  Widget _buildEmptySection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    Event e, {
    required String currentUserId,
    required bool isPast,
    required bool isOngoing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final dateLabel = DateFormat("MMM").format(e.startTime).toUpperCase();
    final dayLabel = DateFormat("d").format(e.startTime);
    final category = e.category?.name;
    final rsvpStatus = _userRsvpStatus(e, currentUserId);
    final isOwner = e.user?.id == currentUserId;
    final hasEnd = e.endTime != null;
    final sameDayEnd = hasEnd &&
        DateFormat('yMd').format(e.startTime) ==
            DateFormat('yMd').format(e.endTime!);
    final startPrimary =
        "${DateFormat("EEE, d MMM").format(e.startTime)} · ${DateFormat("h:mm a").format(e.startTime)}";
    final endLabel = hasEnd
        ? (sameDayEnd
            ? "Ends ${DateFormat("h:mm a").format(e.endTime!)}"
            : "Ends ${DateFormat("EEE, d MMM · h:mm a").format(e.endTime!)}")
        : null;

    final borderColor = cs.outline.withOpacity(isPast ? 0.2 : 0.4);
    final background = isPast
        ? cs.surfaceVariant.withOpacity(0.6)
        : cs.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventScreen(
                event: e,
                currentUserId: currentUserId,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateBadge(
                dateLabel: dateLabel,
                day: dayLabel,
                isPast: isPast,
                isOngoing: isOngoing,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isOngoing)
                          _buildStatusChip(
                            label: "Ongoing",
                            color: cs.secondary,
                            icon: Icons.bolt_rounded,
                          )
                        else if (isPast)
                          _buildStatusChip(
                            label: "Ended",
                            color: cs.outline,
                            icon: Icons.check_circle_outline_rounded,
                            textColor: cs.onSurfaceVariant,
                          )
                        else if ((e.startTime.difference(DateTime.now()).inHours)
                                .abs() <=
                            24)
                          _buildStatusChip(
                            label: "Soon",
                            color: cs.primary,
                            icon: Icons.access_time_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                startPrimary,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              if (endLabel != null)
                                Text(
                                  endLabel,
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((e.location ?? "").isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.location!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (e.user?.username != null ||
                        e.user?.firstName != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.person_rounded,
                              size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            _formatHostName(e),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (category != null && category.isNotEmpty)
                          _buildTagChip(
                            icon: Icons.sell_rounded,
                            label: category,
                            color: cs.primary,
                          ),
                        if (isOwner)
                          _buildTagChip(
                            icon: Icons.star_rounded,
                            label: "You're hosting",
                            color: cs.secondary,
                          ),
                        if (rsvpStatus != null)
                          _buildRsvpBadge(
                            rsvpStatus,
                            cs,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateBadge({
    required String dateLabel,
    required String day,
    required bool isPast,
    required bool isOngoing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final accent = isOngoing
        ? cs.secondary
        : isPast
            ? cs.outline.withOpacity(0.6)
            : cs.primary;

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.7), width: 1.1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dateLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            day,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({
    required String label,
    required Color color,
    required IconData icon,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor ?? color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor ?? color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip({
    required IconData icon,
    required String label,
    required Color color,
    Color? foreground,
  }) {
    final cs = Theme.of(context).colorScheme;
    final textColor = foreground ?? Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: foreground != null
            ? color.withOpacity(0.25)
            : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (foreground != null ? color : cs.outline)
              .withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground ?? color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRsvpBadge(String status, ColorScheme cs) {
    final label = "RSVP: ${_formatRsvpLabel(status)}";
    final color = _rsvpColor(status, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handshake_rounded, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHostName(Event e) {
    final username = e.user?.username?.trim();
    if (username != null && username.isNotEmpty) return username;
    final first = e.user?.firstName?.trim();
    final last = e.user?.lastName?.trim();
    final full = [first, last].whereType<String>().join(" ").trim();
    if (full.isNotEmpty) return full;
    return e.user?.email ?? "Unknown host";
  }

  String? _userRsvpStatus(Event event, String currentUserId) {
    final participations = event.participations;
    if (participations == null) return null;
    for (final participation in participations) {
      if (participation.user?.id == currentUserId) {
        return participation.rsvpStatus;
      }
    }
    return null;
  }

  String _formatRsvpLabel(String status) {
    switch (status) {
      case "accepted":
        return "going";
      case "declined":
        return "not going";
      case "maybe":
        return "maybe";
      default:
        return status;
    }
  }

  Color _rsvpColor(String status, ColorScheme cs) {
    switch (status) {
      case "accepted":
        return Colors.green;
      case "declined":
        return cs.error;
      case "maybe":
        return Colors.orange;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  bool get wantKeepAlive => true;
}
