import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_iframe/flutter_html_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'edit_event.dart';

import '../models/event.dart';
import '../models/event_participation.dart';
import '../repositories/event_repository.dart';
import '../utils/rsvp_helper.dart';

class _RsvpOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _RsvpOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<_RsvpOption> _rsvpOptions = [
  _RsvpOption(
    value: "accepted",
    label: "Going",
    icon: Icons.check_circle_rounded,
    color: Colors.green,
  ),
  _RsvpOption(
    value: "maybe",
    label: "Maybe",
    icon: Icons.help_rounded,
    color: Colors.orange,
  ),
  _RsvpOption(
    value: "declined",
    label: "Can't go",
    icon: Icons.cancel_rounded,
    color: Colors.redAccent,
  ),
];

class EventScreen extends StatefulWidget {
  final Event event;
  final String currentUserId;

  const EventScreen({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen>
    with SingleTickerProviderStateMixin {
  final EventRepository _repo = EventRepository();
  late Future<Event> _eventFuture;
  bool _rsvpLoading = false;
  String? _pendingRsvp;

  YoutubePlayerController? _ytController;
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _eventFuture = _repo.fetchEvent(context, widget.event.id);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _ytController?.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return "-";
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, "0")}";
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps(String location) async {
    final query = Uri.encodeComponent(location);
    final uri =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openImage(String url) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: PhotoView(imageProvider: NetworkImage(url)),
        ),
      ),
    );
  }

  Future<void> _openPdf(String url) async {
    final response = await http.get(Uri.parse(url));
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/temp.pdf");
    await file.writeAsBytes(response.bodyBytes);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("PDF Viewer")),
          body: PDFView(filePath: file.path),
        ),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  EventParticipation? _participationFor(Event event) {
    final parts = event.participations;
    if (parts == null) return null;
    for (final p in parts) {
      if (p.user?.id == widget.currentUserId) return p;
    }
    return null;
  }

  String? _currentRsvpFor(Event event) {
    final status = _participationFor(event)?.rsvpStatus;
    if (status == null || status == "pending" || status.isEmpty) return null;
    return status;
  }

  _RsvpOption? _optionFor(String status) {
    for (final opt in _rsvpOptions) {
      if (opt.value == status) return opt;
    }
    return null;
  }

  String _rsvpLabel(String status) {
    return _optionFor(status)?.label ?? status;
  }

  Future<void> _handleRsvpTap(Event event, String status) async {
    if (_rsvpLoading) return;
    final current = _currentRsvpFor(event);
    if (_pendingRsvp == null && current == status) return;

    if (mounted) {
      setState(() {
        _rsvpLoading = true;
        _pendingRsvp = status;
      });
    }

    try {
      await _repo.updateRsvp(context, event.id, status);
      final refreshed = await _repo.fetchEvent(context, event.id);
      if (mounted) {
        setState(() {
          _eventFuture = Future.value(refreshed);
          _pendingRsvp = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("RSVP updated to ${_rsvpLabel(status)}")),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _pendingRsvp = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Failed to update RSVP. Please try again.",
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _rsvpLoading = false;
        });
      }
    }
  }

  Widget _buildRsvpChoice(
      BuildContext context, Event event, _RsvpOption option, String? selected) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = selected == option.value;
    final disabled = _rsvpLoading;

    final background = isSelected
        ? option.color.withOpacity(0.18)
        : cs.surface.withOpacity(0.35);
    final borderColor =
        isSelected ? option.color : cs.outline.withOpacity(0.4);
    final iconColor = isSelected ? option.color : cs.onSurfaceVariant;
    final textColor = isSelected ? option.color : cs.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: disabled ? null : () => _handleRsvpTap(event, option.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: option.color.withOpacity(0.25),
                      offset: const Offset(0, 10),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(option.icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _maybeRenderYouTube(String text) {
    final ytRegex =
        RegExp(r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]{11})');
    final match = ytRegex.firstMatch(text);
    if (match != null) {
      final videoId = match.group(1)!;
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
      );
      return YoutubePlayer(
        controller: _ytController!,
        showVideoProgressIndicator: true,
      );
    }
    return Html(
      data: text,
      style: {
        "body": Style(
          fontSize: FontSize(16),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      },
      extensions: const [IframeHtmlExtension()],
      onLinkTap: (url, _, __) {
        if (url != null) _openLink(url);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<Event>(
        future: _eventFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData) {
            return const Center(child: Text("Event not found."));
          }

          final e = snapshot.data!;
          final participations = e.participations ?? [];
          final displayParticipations = participations.take(8).toList();
          final remainingCount =
              participations.length > 8 ? participations.length - 8 : 0;
          final selectedStatus = _pendingRsvp ?? _currentRsvpFor(e);
          final summaryOption =
              selectedStatus != null ? _optionFor(selectedStatus) : null;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black.withOpacity(0.6),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                actions: [
                  if (e.user?.id == widget.currentUserId)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.black.withOpacity(0.6),
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditEventScreen(
                                  event: e,
                                  currentUserId: widget.currentUserId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    e.title,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (e.coverImageUrl != null)
                        Image.network(e.coverImageUrl!, fit: BoxFit.cover),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Main Content ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 6),
                          Text(
                              "${_formatDate(e.startTime)} → ${_formatDate(e.endTime)}"),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (e.location != null)
                        InkWell(
                          onTap: () => _openMaps(e.location!),
                          child: Row(
                            children: [
                              const Icon(Icons.place,
                                  size: 18, color: Colors.redAccent),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.location!,
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _animCtrl,
                          curve: Curves.elasticOut,
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: cs.outline.withOpacity(0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: cs.shadow.withOpacity(0.06),
                                blurRadius: 18,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Your RSVP",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: cs.onSurface,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          summaryOption != null
                                              ? "Thanks for keeping everyone in the loop."
                                              : "Let others know if they can count on you.",
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: _rsvpLoading
                                        ? SizedBox(
                                            key: const ValueKey("loader"),
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: summaryOption?.color ??
                                                  cs.primary,
                                            ),
                                          )
                                        : summaryOption != null
                                            ? Container(
                                                key: ValueKey(
                                                    summaryOption.value),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: summaryOption.color
                                                      .withOpacity(0.14),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: summaryOption.color
                                                        .withOpacity(0.4),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      summaryOption.icon,
                                                      size: 16,
                                                      color:
                                                          summaryOption.color,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      summaryOption.label,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: summaryOption
                                                            .color,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : Container(
                                                key: const ValueKey(
                                                    "no-response"),
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs.surface
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                  border: Border.all(
                                                    color: cs.outline
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .hourglass_bottom_rounded,
                                                      size: 16,
                                                      color: cs
                                                          .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      "No response yet",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: cs
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: _rsvpOptions
                                    .map(
                                      (opt) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: _buildRsvpChoice(
                                            context,
                                            e,
                                            opt,
                                            selectedStatus,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _maybeRenderYouTube(e.description),
                      const SizedBox(height: 24),

                      // ✅ Participants
                      if (participations.isNotEmpty) ...[
                        Text(
                          "Participants",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.secondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 64,
                          child: Stack(
                            children: [
                              for (int i = 0;
                                  i < displayParticipations.length;
                                  i++)
                                Positioned(
                                  left: i * 40.0,
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundImage: displayParticipations[i]
                                                    .user
                                                    ?.avatarUrl !=
                                                null
                                            ? NetworkImage(displayParticipations[i]
                                                .user!
                                                .avatarUrl!)
                                            : null,
                                        backgroundColor: Colors.grey.shade300,
                                        child: displayParticipations[i]
                                                    .user
                                                    ?.avatarUrl ==
                                                null
                                            ? Text(
                                                (displayParticipations[i]
                                                            .user
                                                            ?.username ??
                                                        displayParticipations[i]
                                                            .user
                                                            ?.email ??
                                                        "?")[0]
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              )
                                            : null,
                                      ),
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: rsvpColor(
                                                displayParticipations[i]
                                                    .rsvpStatus),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (remainingCount > 0)
                                Positioned(
                                  left: displayParticipations.length * 40.0,
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: cs.primary,
                                    child: Text(
                                      "+$remainingCount",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ✅ Files
                      if (e.files != null && e.files!.isNotEmpty) ...[
                        Text(
                          "Files",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        ...e.files!.map((f) {
                          return ListTile(
                            leading: Icon(
                              f.isImage
                                  ? Icons.image
                                  : f.isPdf
                                      ? Icons.picture_as_pdf
                                      : Icons.insert_drive_file,
                              color: cs.primary,
                            ),
                            title: Text(f.filename),
                            onTap: () {
                              if (f.isImage) {
                                _openImage(f.url);
                              } else if (f.isPdf) {
                                _openPdf(f.url);
                              } else {
                                _openExternal(f.url);
                              }
                            },
                          );
                        }),
                        const SizedBox(height: 24),
                      ],

                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
