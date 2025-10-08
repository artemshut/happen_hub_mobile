// lib/screens/dashboard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../services/auth_service.dart';
import '../models/event.dart';
import '../repositories/event_repository.dart';
import '../providers/user_provider.dart';
import 'create_event.dart';
import 'event.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final EventRepository _repo = EventRepository();
  late Future<List<Event>> _eventsFuture;
  final AuthService _authService = AuthService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Event>> _groupedEvents = {};

  DateTime _dayKey(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  DateTime _stripTime(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  String _formatTime(DateTime dt) =>
      "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";

  String _eventTimeLabelForDay(Event event, DateTime day) {
    final dayOnly = _stripTime(day);
    final startDay = _stripTime(event.startTime);
    final endDay = _stripTime(event.endTime ?? event.startTime);
    final hasEnd = event.endTime != null;

    if (isSameDay(dayOnly, startDay)) {
      if (!hasEnd || isSameDay(event.startTime, event.endTime!)) {
        return _formatTime(event.startTime) +
            (hasEnd ? " → ${_formatTime(event.endTime!)}" : "");
      }
      return "${_formatTime(event.startTime)} • continues";
    }

    if (hasEnd && isSameDay(dayOnly, endDay)) {
      return "Ends ${_formatTime(event.endTime!)}";
    }

    if (hasEnd &&
        dayOnly.isAfter(startDay) &&
        dayOnly.isBefore(endDay)) {
      return "All day • ongoing";
    }

    return "All day";
  }

  Widget _buildCalendarDay(
    BuildContext context,
    DateTime day,
    DateTime focusedDay, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
  }) {
    final cs = Theme.of(context).colorScheme;
    final events = _getEventsForDay(day);
    final hasEvents = events.isNotEmpty;
    final dayOnly = _stripTime(day);

    bool connectsLeft = false;
    bool connectsRight = false;

    for (final event in events) {
      final start = _stripTime(event.startTime);
      final end = _stripTime(event.endTime ?? event.startTime);
      if (end.isBefore(start)) continue;

      if (dayOnly.isAfter(start) && !dayOnly.isAfter(end)) {
        connectsLeft = true;
      }
      if (dayOnly.isBefore(end) && !dayOnly.isBefore(start)) {
        connectsRight = true;
      }
    }

    final onlySingleDay = hasEvents &&
        events.every((event) {
          final start = _stripTime(event.startTime);
          final end = _stripTime(event.endTime ?? event.startTime);
          return isSameDay(start, end);
        });

    final borderRadius = !hasEvents
        ? BorderRadius.circular(12)
        : (!connectsLeft && !connectsRight) || onlySingleDay
            ? BorderRadius.circular(16)
            : connectsLeft && connectsRight
                ? BorderRadius.circular(6)
                : connectsLeft
                    ? const BorderRadius.horizontal(
                        left: Radius.circular(6),
                        right: Radius.circular(16),
                      )
                    : const BorderRadius.horizontal(
                        left: Radius.circular(16),
                        right: Radius.circular(6),
                      );

    final margin = EdgeInsets.only(
      left: connectsLeft ? 2 : 6,
      right: connectsRight ? 2 : 6,
      top: 6,
      bottom: 6,
    );

    final List<Color>? gradientColors =
        hasEvents || isSelected
            ? (isSelected
                ? [
                    cs.primary,
                    cs.secondary,
                  ]
                : [
                    cs.primary.withOpacity(isOutside ? 0.15 : 0.25),
                    (cs.tertiary ?? cs.secondary)
                        .withOpacity(isOutside ? 0.1 : 0.2),
                  ])
            : null;

    final gradient = gradientColors != null
        ? LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    final textColor = isSelected
        ? cs.onPrimary
        : isOutside
            ? cs.onSurface.withOpacity(0.3)
            : cs.onSurface;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? Colors.transparent : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: isToday
            ? Border.all(
                color: isSelected
                    ? cs.onPrimary.withOpacity(0.6)
                    : cs.primary.withOpacity(0.8),
                width: 1.4,
              )
            : null,
        boxShadow: hasEvents || isSelected
            ? [
                BoxShadow(
                  color: (isSelected
                          ? cs.primary.withOpacity(0.35)
                          : cs.primary.withOpacity(isOutside ? 0.12 : 0.22)),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              "${day.day}",
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasEvents)
            Positioned(
              bottom: 6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Colors.white.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    events.length.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _eventsFuture = _repo.fetchEvents(context);
  }

  /// 🔔 Init push notifications with deep link support
  Future<void> _initNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Ask permissions (iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint("🔔 Notification permission: ${settings.authorizationStatus}");

    // Current FCM token
    String? token = await messaging.getToken();
    debugPrint("📱 Initial FCM Token: $token");
    if (token != null) await _authService.sendFcmTokenToBackend();

    // Foreground message
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 Foreground message: ${message.notification?.title}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification?.title ?? "New message")),
        );
      }
    });

    // Background → app opened by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🚀 Opened from notification: ${message.data}");
      if (message.data.containsKey("event_id")) {
        final eventId = message.data["event_id"];
        _openEventById(eventId);
      }
    });

    // Terminated → app launched by tapping notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null && initialMessage.data.containsKey("event_id")) {
      final eventId = initialMessage.data["event_id"];
      _openEventById(eventId);
    }
  }

  /// 📌 Navigate to EventScreen by eventId
  Future<void> _openEventById(String eventId) async {
    try {
      final event = await _repo.fetchEvent(context, eventId);
      if (!mounted) return;
      final userId =
          Provider.of<UserProvider>(context, listen: false).user?.id ?? "";

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventScreen(event: event, currentUserId: userId),
        ),
      );
    } catch (e) {
      debugPrint("❌ Failed to open event $eventId: $e");
    }
  }

  Map<DateTime, List<Event>> _groupEventsByDay(List<Event> events) {
    final Map<DateTime, List<Event>> data = {};
    for (var e in events) {
      final start = _stripTime(e.startTime);
      final end = _stripTime(e.endTime ?? e.startTime);
      DateTime cursor = start;
      while (!cursor.isAfter(end)) {
        final key = _dayKey(cursor);
        data.putIfAbsent(key, () => []);
        if (!data[key]!.contains(e)) {
          data[key]!.add(e);
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return data;
  }

  List<Event> _getEventsForDay(DateTime day) {
    final d = _dayKey(day);
    return _groupedEvents[d] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = Provider.of<UserProvider>(context).user;
    final currentUserId = currentUser?.id ?? "";

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newEvent = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (newEvent != null && mounted) {
            setState(() => _eventsFuture = _repo.fetchEvents(context));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Event created")),
            );
          }
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text("Create"),
      ),
      body: CustomScrollView(
        slivers: [
          // 🌈 Gradient AppBar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Dashboard",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary, cs.tertiary ?? cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // 📅 Calendar + Events
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FutureBuilder<List<Event>>(
                future: _eventsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No events yet"));
                  }

                  final events = snapshot.data!;
                  _groupedEvents = _groupEventsByDay(events);

                  final now = DateTime.now();
                  final upcoming = events.where((e) => e.startTime.isAfter(now)).toList();
                  final past = events.where((e) => e.startTime.isBefore(now)).toList();
                  final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Card(
                        margin: const EdgeInsets.only(bottom: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2030, 12, 31),
                            focusedDay: _focusedDay,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            eventLoader: _getEventsForDay,
                            headerStyle: HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                            ),
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              markersMaxCount: 0,
                              todayDecoration: const BoxDecoration(),
                              selectedDecoration: const BoxDecoration(),
                              weekendTextStyle:
                                  TextStyle(color: cs.secondary),
                            ),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) =>
                                  _buildCalendarDay(
                                context,
                                day,
                                focusedDay,
                                isSelected: isSameDay(_selectedDay, day),
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: day.month != focusedDay.month,
                              ),
                              outsideBuilder: (context, day, focusedDay) =>
                                  _buildCalendarDay(
                                context,
                                day,
                                focusedDay,
                                isSelected: isSameDay(_selectedDay, day),
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: true,
                              ),
                              todayBuilder: (context, day, focusedDay) =>
                                  _buildCalendarDay(
                                context,
                                day,
                                focusedDay,
                                isSelected: isSameDay(_selectedDay, day),
                                isToday: true,
                                isOutside: day.month != focusedDay.month,
                              ),
                              selectedBuilder: (context, day, focusedDay) =>
                                  _buildCalendarDay(
                                context,
                                day,
                                focusedDay,
                                isSelected: true,
                                isToday: isSameDay(day, DateTime.now()),
                                isOutside: day.month != focusedDay.month,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Events for selected day
                      if (selectedEvents.isNotEmpty) ...[
                        Text("Events on this day",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                )),
                        const SizedBox(height: 8),
                        Column(
                          children: selectedEvents.map((e) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    cs.primary.withOpacity(0.9),
                                    cs.secondary.withOpacity(0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: cs.primary.withOpacity(0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      Colors.white.withOpacity(0.25),
                                  child: const Icon(Icons.event, color: Colors.white),
                                ),
                                title: Text(
                                  e.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  _eventTimeLabelForDay(
                                      e, _selectedDay ?? e.startTime),
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EventScreen(
                                        event: e,
                                        currentUserId: currentUserId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Upcoming Events
                      if (upcoming.isNotEmpty) ...[
                        Text("Upcoming Events",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                )),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: upcoming.length,
                            itemBuilder: (context, i) {
                              final e = upcoming[i];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EventScreen(
                                        event: e,
                                        currentUserId: currentUserId,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 260,
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (e.coverImageUrl != null)
                                          Image.network(e.coverImageUrl!,
                                              fit: BoxFit.cover)
                                        else
                                          Container(color: cs.primary),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.black.withOpacity(0.6),
                                                Colors.transparent
                                              ],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Spacer(),
                                              Text(e.title,
                                                  style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 16)),
                                              Text(
                                                "${e.startTime.day}/${e.startTime.month}/${e.startTime.year}",
                                                style: const TextStyle(
                                                    color: Colors.white70),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Past Events
                      if (past.isNotEmpty) ...[
                        Text("Past Events",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.secondary,
                                )),
                        const SizedBox(height: 12),
                        Column(
                          children: past.map((e) {
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: const Icon(Icons.history),
                                title: Text(
                                  e.title,
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Text(
                                    "Ended ${e.endTime?.toLocal().toString().split(' ').first ?? ''}"),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => EventScreen(
                                        event: e,
                                        currentUserId: currentUserId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
