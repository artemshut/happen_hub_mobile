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

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? trailing;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _HeroTagChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroTagChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );

    final decorated = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: content,
    );

    if (onTap == null) {
      return decorated;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: decorated,
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Gradient? gradient;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
        gradient: gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.surfaceVariant.withOpacity(0.85),
                cs.surface.withOpacity(0.7),
              ],
            ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

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
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
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

  Future<void> _contactHost(String email) async {
    if (email.isEmpty) return;
    final uri = Uri(
      scheme: "mailto",
      path: email,
      queryParameters: {
        "subject": "Hi! I'm interested in ${widget.event.title}"
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
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

    final previousOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final maxScroll = _scrollController.position.maxScrollExtent;
          final targetOffset =
              previousOffset.clamp(0.0, maxScroll);
          _scrollController.jumpTo(targetOffset);
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
          final hostName = e.user != null
              ? (() {
                  final username = e.user!.username?.trim();
                  if (username != null && username.isNotEmpty) return username;
                  final fullName = [
                    e.user!.firstName?.trim(),
                    e.user!.lastName?.trim(),
                  ].whereType<String>().join(" ").trim();
                  if (fullName.isNotEmpty) return fullName;
                  return e.user!.email;
                })()
              : null;
          final categoryLabel = e.category?.name;
          final hasCategory =
              categoryLabel != null && categoryLabel.trim().isNotEmpty;
          final visibilityLabel = e.visibility;
          final hasVisibility =
              visibilityLabel != null && visibilityLabel.trim().isNotEmpty;
          final hostInitial = e.user != null
              ? (hostName != null && hostName.isNotEmpty
                  ? hostName[0].toUpperCase()
                  : (e.user!.email.isNotEmpty
                      ? e.user!.email[0].toUpperCase()
                      : "?"))
              : null;
          final hostTag = e.user?.tag?.trim().isNotEmpty == true
              ? e.user!.tag!.trim()
              : null;

          return CustomScrollView(
            controller: _scrollController,
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
                      Positioned(
                        bottom: 24,
                        left: 16,
                        right: 16,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (hasCategory)
                              _HeroTagChip(
                                icon: Icons.sell,
                                label: categoryLabel!.trim(),
                              ),
                            if (hasVisibility)
                              _HeroTagChip(
                                icon: Icons.lock_open_rounded,
                                label: visibilityLabel!
                                    .trim()
                                    .replaceFirstMapped(
                                      RegExp(r'^[a-z]'),
                                      (m) => m.group(0)!.toUpperCase(),
                                    ),
                              ),
                          ],
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
                      _SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.info_outline_rounded,
                              label: "Event details",
                              color: cs.primary,
                              trailing: participations.isNotEmpty
                                  ? "${participations.length} attending"
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _InfoBadge(
                                  icon: Icons.event_available_rounded,
                                  label: e.endTime != null
                                      ? "${_formatDate(e.startTime)} → ${_formatDate(e.endTime)}"
                                      : _formatDate(e.startTime),
                                  color: cs.primary,
                                ),
                                if ((e.location ?? "").isNotEmpty)
                                  _InfoBadge(
                                    icon: Icons.place_outlined,
                                    label: e.location!,
                                    color: Colors.indigoAccent,
                                    onTap: () => _openMaps(e.location!),
                                  ),
                                if (hasCategory)
                                  _InfoBadge(
                                    icon: Icons.sell_rounded,
                                    label: categoryLabel!.trim(),
                                    color: cs.secondary,
                                  ),
                                if (hasVisibility)
                                  _InfoBadge(
                                    icon: Icons.lock_open_rounded,
                                    label: visibilityLabel!
                                        .trim()
                                        .replaceFirstMapped(
                                      RegExp(r'^[a-z]'),
                                      (m) => m.group(0)!.toUpperCase(),
                                    ),
                                    color: cs.tertiary,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (e.user != null)
                        _SurfaceCard(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              cs.primaryContainer.withOpacity(0.95),
                              cs.secondaryContainer.withOpacity(0.85),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundImage: e.user!.avatarUrl != null &&
                                        e.user!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(e.user!.avatarUrl!)
                                    : null,
                                backgroundColor:
                                    Colors.white.withOpacity(0.25),
                                child: (e.user!.avatarUrl ?? "").isEmpty
                                    ? Text(
                                        hostInitial ?? "?",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hostName ?? e.user!.email,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: cs.onPrimaryContainer
                                                .withOpacity(0.9),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      e.user!.email,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: cs.onPrimaryContainer
                                                .withOpacity(0.8),
                                          ),
                                    ),
                                    if (hostTag != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 6.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            hostTag,
                                            style: TextStyle(
                                              color: cs.onPrimaryContainer,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (e.user!.email.isNotEmpty)
                                FilledButton.tonalIcon(
                                  onPressed: () => _contactHost(e.user!.email),
                                  icon: const Icon(Icons.email_rounded),
                                  label: const Text("Contact host"),
                                  style: FilledButton.styleFrom(
                                    foregroundColor:
                                        cs.onPrimaryContainer.withOpacity(0.9),
                                    backgroundColor:
                                        Colors.white.withOpacity(0.25),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (e.user != null) const SizedBox(height: 18),

                      ScaleTransition(
                        scale: CurvedAnimation(
                          parent: _animCtrl,
                          curve: Curves.elasticOut,
                        ),
                        child: _SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.handshake_rounded,
                                label: "Your RSVP",
                                color: cs.primary,
                                trailing: summaryOption?.label,
                              ),
                              const SizedBox(height: 8),
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
                              const SizedBox(height: 20),
                              Row(
                                children: _rsvpOptions
                                    .map(
                                      (opt) => Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
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
                              const SizedBox(height: 16),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _rsvpLoading
                                    ? Row(
                                        key: const ValueKey("loader"),
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: summaryOption?.color ??
                                                  cs.primary,
                                            ),
                                          ),
                                        ],
                                      )
                                    : summaryOption != null
                                        ? Row(
                                            key: ValueKey(
                                                summaryOption.value),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                summaryOption.icon,
                                                size: 18,
                                                color: summaryOption.color,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "Marked as ${summaryOption.label}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: summaryOption.color,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            key: const ValueKey(
                                                "no-response"),
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.hourglass_bottom_rounded,
                                                size: 18,
                                                color: cs.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "No response yet",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionTitle(
                              icon: Icons.subject_rounded,
                              label: "About this event",
                              color: cs.secondary,
                            ),
                            const SizedBox(height: 18),
                            _maybeRenderYouTube(e.description),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (participations.isNotEmpty) ...[
                        _SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.people_alt_rounded,
                                label: "Participants",
                                color: cs.secondary,
                                trailing: participations.length > 8
                                    ? "+$remainingCount more"
                                    : "${participations.length} attending",
                              ),
                              const SizedBox(height: 16),
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
                                              backgroundImage:
                                                  displayParticipations[i]
                                                              .user
                                                              ?.avatarUrl !=
                                                          null
                                                      ? NetworkImage(
                                                          displayParticipations[
                                                                  i]
                                                              .user!
                                                              .avatarUrl!)
                                                      : null,
                                              backgroundColor:
                                                  Colors.grey.shade300,
                                              child: displayParticipations[i]
                                                          .user
                                                          ?.avatarUrl ==
                                                      null
                                                  ? Text(
                                                      (displayParticipations[i]
                                                                  .user
                                                                  ?.username ??
                                                              displayParticipations[
                                                                      i]
                                                                  .user
                                                                  ?.email ??
                                                              "?")[0]
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
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
                                                        .rsvpStatus,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (remainingCount > 0)
                                      Positioned(
                                        left:
                                            displayParticipations.length * 40.0,
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if (e.files != null && e.files!.isNotEmpty) ...[
                        _SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.attach_file_rounded,
                                label: "Attachments",
                                color: cs.primary,
                                trailing:
                                    "${e.files!.length} file${e.files!.length > 1 ? 's' : ''}",
                              ),
                              const SizedBox(height: 16),
                              ...List.generate(e.files!.length, (index) {
                                final f = e.files![index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        index == e.files!.length - 1 ? 0 : 12,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () {
                                      if (f.isImage) {
                                        _openImage(f.url);
                                      } else if (f.isPdf) {
                                        _openPdf(f.url);
                                      } else {
                                        _openExternal(f.url);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            cs.surface.withOpacity(0.55),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color:
                                              cs.outline.withOpacity(0.12),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            f.isImage
                                                ? Icons.image_rounded
                                                : f.isPdf
                                                    ? Icons.picture_as_pdf
                                                    : Icons.insert_drive_file,
                                            color: f.isPdf
                                                ? Colors.redAccent
                                                : cs.primary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              f.filename,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.open_in_new_rounded,
                                            size: 18,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
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
