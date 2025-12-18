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
  String? _selectedCategory;

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

  DateTime _eventEndTime(Event event) => event.endTime ?? event.startTime;

  bool _isPastEvent(Event event, DateTime reference) {
    return _eventEndTime(event).isBefore(reference);
  }

  String _greetingLine(String? firstName, String? username) {
    final trimmed = firstName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return "Hey $trimmed, ready for tonight?";
    }
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) {
      return "Hey @$handle, ready for tonight?";
    }
    return "Hey there, ready for tonight?";
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

    final highlightFill = isSelected
        ? cs.primary.withOpacity(0.14)
        : hasEvents
            ? cs.primary.withOpacity(isOutside ? 0.08 : 0.12)
            : Colors.transparent;

    final halo = hasEvents
        ? Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cs.primary.withOpacity(0.25),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
          )
        : const SizedBox.shrink();

    final textColor = isSelected
        ? cs.onSurface
        : isOutside
            ? cs.onSurface.withOpacity(0.35)
            : cs.onSurface;

    final dots = <Widget>[];
    final dotColor = cs.primary;
    var dotCount = events.length;
    if (dotCount > 3) dotCount = 3;
    for (var i = 0; i < dotCount; i++) {
      dots.add(Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: dotColor.withOpacity(0.85 - (i * 0.15)),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: dotColor.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
      ));
    }
    if (events.length > 3) {
      dots.add(Text(
        "+${events.length - 3}",
        style: TextStyle(
          fontSize: 10,
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ));
    }

    final markerRow = AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: hasEvents ? 1 : 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: dots,
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : hasEvents
                  ? cs.primary.withOpacity(isOutside ? 0.25 : 0.4)
                  : Colors.transparent,
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: hasEvents || isSelected
            ? [
                BoxShadow(
                  color: cs.primary.withOpacity(isSelected ? 0.35 : 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                color: highlightFill,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (hasEvents)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: halo,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isToday) ...[
                  Text(
                    "NOW",
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  "${day.day}",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(height: 6, child: markerRow),
              ],
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

  bool _isEventOngoing(Event event, DateTime reference) {
    final end = event.endTime ?? event.startTime;
    return !reference.isBefore(event.startTime) &&
        !reference.isAfter(end);
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
            expandedHeight: 100,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 16,
                bottom: 12,
                end: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dashboard",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _greetingLine(currentUser?.firstName, currentUser?.username),
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimary.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary,
                      cs.secondary,
                      cs.tertiary ?? cs.secondary,
                    ],
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
                  final upcoming = events.where((e) => !_isPastEvent(e, now)).toList();
                  final past = events.where((e) => _isPastEvent(e, now)).toList();
                  final selectedEvents =
                      _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
                  upcoming.sort((a, b) => a.startTime.compareTo(b.startTime));
                  past.sort((a, b) => _eventEndTime(b).compareTo(_eventEndTime(a)));

                  final categories = events
                      .map((e) => e.category?.name?.trim())
                      .whereType<String>()
                      .where((name) => name.isNotEmpty)
                      .toSet()
                      .toList()
                    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

                  final filteredUpcoming = _selectedCategory == null
                      ? upcoming
                      : upcoming
                          .where((e) =>
                              (e.category?.name ?? "").trim() ==
                              _selectedCategory)
                          .toList();

                  final nextEvent =
                      filteredUpcoming.isNotEmpty ? filteredUpcoming.first : null;

                  final visiblePast = past.take(5).toList();
                  final hiddenPastCount = past.length - visiblePast.length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar
                      Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border:
                              Border.all(color: cs.outline.withOpacity(0.08)),
                          color: cs.surface.withOpacity(0.65),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
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
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: cs.onSurface,
                              ),
                              leftChevronIcon: Icon(
                                Icons.chevron_left_rounded,
                                color: cs.onSurface,
                              ),
                              rightChevronIcon: Icon(
                                Icons.chevron_right_rounded,
                                color: cs.onSurface,
                              ),
                              headerPadding: const EdgeInsets.only(bottom: 12),
                            ),
                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              markersMaxCount: 0,
                              todayDecoration: const BoxDecoration(),
                              selectedDecoration: const BoxDecoration(),
                              weekendTextStyle: TextStyle(
                                color: cs.onSurface.withOpacity(0.85),
                              ),
                              defaultTextStyle: TextStyle(
                                color: cs.onSurface.withOpacity(0.85),
                              ),
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

                      if (nextEvent != null) ...[
                        _buildSectionTitle(
                          context,
                          icon: Icons.bolt_rounded,
                          title: "Next up",
                          subtitle:
                              "${nextEvent.startTime.day}/${nextEvent.startTime.month} • ${_formatTime(nextEvent.startTime)}",
                          color: cs.secondary,
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EventScreen(
                                  event: nextEvent,
                                  currentUserId: currentUserId,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 170,
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.secondary.withOpacity(0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (nextEvent.coverImageUrl != null)
                                    Image.network(
                                      nextEvent.coverImageUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            cs.secondaryContainer,
                                            cs.primaryContainer,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.black87,
                                          Colors.transparent,
                                        ],
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.access_time,
                                                color: Colors.white70),
                                            const SizedBox(width: 6),
                                            Text(
                                              _eventTimeLabelForDay(
                                                  nextEvent, nextEvent.startTime),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Text(
                                          nextEvent.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if ((nextEvent.location ?? "")
                                            .isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.place,
                                                  size: 16,
                                                  color: Colors.white70),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  nextEvent.location!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                  ),
                                                ),
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
                        ),
                      ],

                      if (categories.isNotEmpty) ...[
                        _buildSectionTitle(
                          context,
                          icon: Icons.filter_alt_rounded,
                          title: "Filter by category",
                          subtitle: "Tap to focus upcoming events",
                          color: cs.primary,
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _CategoryFilterChip(
                                label: "All",
                                selected: _selectedCategory == null,
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                },
                              ),
                              const SizedBox(width: 10),
                              ...categories.map(
                                (cat) => Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: _CategoryFilterChip(
                                    label: cat,
                                    selected: _selectedCategory == cat,
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory =
                                            _selectedCategory == cat ? null : cat;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Upcoming Events
                      if (upcoming.isNotEmpty) ...[
                        Text(
                            _selectedCategory == null
                                ? "Upcoming Events"
                                : "Upcoming • $_selectedCategory",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                )),
                        const SizedBox(height: 12),
                        if (filteredUpcoming.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              "No events in this category yet. Try a different filter or create one!",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          )
                        else
                          SizedBox(
                            height: 220,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: filteredUpcoming.length,
                              itemBuilder: (context, i) {
                                final e = filteredUpcoming[i];
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
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    cs.primary.withOpacity(0.85),
                                                    cs.secondary.withOpacity(0.85),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                            ),
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.black.withOpacity(0.7),
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
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule,
                                                        size: 16,
                                                        color: Colors.white
                                                            .withOpacity(0.85)),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "${_formatTime(e.startTime)} • ${e.startTime.day}/${e.startTime.month}",
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Text(e.title,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        fontSize: 16)),
                                                if ((e.location ?? "")
                                                    .isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(
                                                        top: 6.0),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.place,
                                                            size: 14,
                                                            color:
                                                                Colors.white70),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            e.location!,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white70,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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
                          children: visiblePast.map((e) {
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
                        if (hiddenPastCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "+$hiddenPastCount more in history",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
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

  Widget _buildSectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final resolved = color ?? cs.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: resolved.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: resolved),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
class _CategoryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? cs.primary.withOpacity(0.16)
                : cs.surfaceVariant.withOpacity(0.6),
            border: Border.all(
              color: selected
                  ? cs.primary
                  : cs.outline.withOpacity(0.25),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
