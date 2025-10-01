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
      final day =
          DateTime.utc(e.startTime.year, e.startTime.month, e.startTime.day);
      data.putIfAbsent(day, () => []);
      data[day]!.add(e);
    }
    return data;
  }

  List<Event> _getEventsForDay(DateTime day) {
    final d = DateTime.utc(day.year, day.month, day.day);
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
                              todayDecoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                              ),
                              weekendTextStyle:
                                  TextStyle(color: cs.secondary),
                              outsideDaysVisible: false,
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
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(Icons.event),
                                title: Text(e.title),
                                subtitle: Text(
                                    "${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}"),
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