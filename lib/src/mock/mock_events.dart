import '../models/event.dart';

final mockEvents = [
  Event(
    id: '1',
    title: 'Techno Night',
    description: 'Rave with friends downtown.',
    startTime: DateTime.now().add(const Duration(days: 2, hours: 20)),
    endTime: DateTime.now().add(const Duration(days: 3, hours: 2)),
    location: "Downtown Club, Kraków",
    // slug: "techno-night",
    // userId: "1",
  ),
  Event(
    id: '2',
    title: 'Snowboarding Trip',
    description: 'Day trip to Zakopane.',
    startTime: DateTime.now().add(const Duration(days: 7, hours: 7)),
    endTime: DateTime.now().add(const Duration(days: 7, hours: 20)),
    location: "Zakopane, Poland",
    // slug: "snowboarding-trip",
    // userId: "2",
  ),
];
