// lib/screens/events_list.dart
import 'package:flutter/material.dart';
import '../repositories/event_repository.dart';
import '../models/event.dart';
import 'event.dart'; // EventScreen
import 'create_event.dart'; // CreateEventScreen

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});

  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  final EventRepository _repo = EventRepository();
  late Future<List<Event>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _repo.fetchEvents(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("All Events"),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newEvent = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (newEvent != null && mounted) {
            setState(() {
              _eventsFuture = _repo.fetchEvents(context);
            });
          }
        },
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.add),
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
          final upcoming =
              events.where((e) => e.startTime.isAfter(now)).toList();
          final past = events.where((e) => e.startTime.isBefore(now)).toList();

          return ListView(
            children: [
              if (upcoming.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Upcoming Events",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                ),
                ...upcoming.map((e) => _buildEventCard(e, cs, showRsvp: true)),
              ],
              if (past.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Past Events",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.secondary,
                        ),
                  ),
                ),
                ...past.map((e) => _buildEventCard(e, cs)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Event e, ColorScheme cs, {bool showRsvp = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: e.coverImageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  e.coverImageUrl!,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.event, color: Colors.white),
              ),
        title: Text(
          e.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${e.startTime.day}/${e.startTime.month}/${e.startTime.year} • ${e.location ?? 'No location'}",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            // if (showRsvp && e.rsvpStatus != null) // 👈 show RSVP if available
            //   Padding(
            //     padding: const EdgeInsets.only(top: 4),
            //     child: Text(
            //       "RSVP: ${e.rsvpStatus}", // e.g. going / maybe / not going
            //       style: TextStyle(
            //         fontWeight: FontWeight.w500,
            //         color: cs.primary,
            //       ),
            //     ),
            //   ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventScreen(event: e),
            ),
          );
        },
      ),
    );
  }
}