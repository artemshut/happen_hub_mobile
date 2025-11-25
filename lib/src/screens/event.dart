import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_iframe/flutter_html_iframe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'edit_event.dart';

import '../models/event.dart';
import '../models/event_participation.dart';
import '../repositories/event_repository.dart';
import '../utils/rsvp_helper.dart';
import 'event_comments_screen.dart';

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
    final accent = Color.lerp(
          theme.colorScheme.onSurface,
          color,
          0.35,
        ) ??
        theme.colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Icon(icon, color: accent, size: 22),
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

  const _HeroTagChip({required this.icon, required this.label});

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
    final accent = Color.lerp(cs.onSurface, color, 0.25) ?? cs.onSurface;
    final background = Color.alphaBlend(
      Colors.black.withOpacity(0.65),
      cs.surface,
    );
    final borderColor = Color.lerp(cs.outline, accent, 0.15);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w600, color: accent),
          ),
        ),
      ],
    );

    final decorated = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? cs.outline.withOpacity(0.3)),
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

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    final iconBadge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: cs.onSurface.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Icon(icon, size: 20, color: cs.onSurface),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconBadge,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    letterSpacing: 3,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                Icons.north_east_rounded,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}

class _ExpandableDescription extends StatefulWidget {
  final String text;
  final Widget content;

  const _ExpandableDescription({
    required this.text,
    required this.content,
  });

  @override
  State<_ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<_ExpandableDescription> {
  bool _expanded = false;

  String get _rawText => widget.text
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ');

  String get _plainText =>
      _rawText.replaceAll(RegExp(r'\s+'), ' ').trim();

  bool get _isLong =>
      _plainText.length > 280 || _rawText.split('\n').length > 4;

  @override
  Widget build(BuildContext context) {
    if (!_isLong) {
      return widget.content;
    }

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final preview = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withOpacity(0.12)),
      ),
      child: Stack(
        children: [
          Text(
            _plainText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      cs.surface.withOpacity(0.85),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedCrossFade(
          firstChild: preview,
          secondChild: widget.content,
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeOut,
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            ),
            label: Text(_expanded ? "Hide manifesto" : "Read manifesto"),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurface,
              textStyle: textTheme.labelLarge?.copyWith(letterSpacing: 1.2),
            ),
          ),
        ),
      ],
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
    final base = Color.lerp(Colors.black, cs.surface, 0.7);
    final overlay = Color.lerp(Colors.black, cs.surfaceVariant, 0.85);

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                overlay ?? cs.surfaceVariant.withOpacity(0.8),
                base ?? cs.surface.withOpacity(0.65),
              ],
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MediaTile extends StatelessWidget {
  final EventFile file;
  final ColorScheme colorScheme;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  const _MediaTile({
    required this.file,
    required this.colorScheme,
    required this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final isPdf = file.isPdf;
    final isImage = file.isImage;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outline.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Icon(
                isImage
                    ? Icons.image_rounded
                    : isPdf
                    ? Icons.picture_as_pdf
                    : Icons.insert_drive_file,
                color: isPdf ? Colors.redAccent : cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file.filename,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                color: cs.onSurfaceVariant,
                onPressed: onOpen,
              ),
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: cs.error,
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
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
  bool _uploadingMedia = false;

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
    final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$query",
    );
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
        "subject": "Hi! I'm interested in ${widget.event.title}",
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
      if (p.user?.id == widget.currentUserId ||
          p.userId == widget.currentUserId) {
        return p;
      }
    }
    return null;
  }

  bool _canUploadMedia(Event event) {
    final visibility = event.visibility?.toLowerCase();
    final restricted = visibility == 'private' || visibility == 'friends';
    if (!restricted) return false;

    if (event.user?.id == widget.currentUserId) return true;

    final status = _normalizeStatus(_participationFor(event)?.rsvpStatus);
    return status == 'accepted';
  }

  Future<void> _pickAndUploadMedia(Event event) async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null || result.files.isEmpty) return;

      final files = <File>[];
      for (final file in result.files) {
        if (file.path != null) {
          files.add(File(file.path!));
        } else if (file.bytes != null) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File("${tempDir.path}/${file.name}");
          await tempFile.writeAsBytes(file.bytes!);
          files.add(tempFile);
        }
      }
      if (files.isEmpty) return;

      setState(() => _uploadingMedia = true);
      final updated = await _repo.uploadEventFiles(
        eventId: event.id,
        files: files,
      );
      if (!mounted) return;
      setState(() {
        _eventFuture = Future.value(updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Files uploaded")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Upload failed: \$e")));
    } finally {
      if (mounted) {
        setState(() => _uploadingMedia = false);
      }
    }
  }

  Future<void> _deleteMediaFile(Event event, String signedId) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Remove file?"),
            content: const Text("This attachment will disappear for everyone."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _uploadingMedia = true);
      final updated = await _repo.deleteEventFile(
        eventId: event.id,
        signedId: signedId,
      );
      if (!mounted) return;
      setState(() {
        _eventFuture = Future.value(updated);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("File removed")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to remove: \$e")));
    } finally {
      if (mounted) {
        setState(() => _uploadingMedia = false);
      }
    }
  }

  Widget _buildRsvpSection({
    required BuildContext context,
    required Event event,
    required ColorScheme colorScheme,
    required String? selectedStatus,
    required _RsvpOption? summaryOption,
  }) {
    final cs = colorScheme;

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.emoji_people_rounded,
            label: "RSVP",
            color: cs.primary,
            trailing:
                summaryOption?.label ??
                (selectedStatus != null ? _rsvpLabel(selectedStatus) : null),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < _rsvpOptions.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _buildRsvpChoice(
                    context,
                    event,
                    _rsvpOptions[i],
                    selectedStatus,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_rsvpLoading) const LinearProgressIndicator(minHeight: 3),
          if (_rsvpLoading) const SizedBox(height: 12),
          Text(
            "Tap an option to update your RSVP instantly.",
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab({
    required BuildContext context,
    required Event event,
    required ColorScheme colorScheme,
    required String? hostName,
    required String? hostInitial,
    required String? hostTag,
    required String? categoryLabel,
    required bool hasCategory,
    required String? visibilityLabel,
    required bool hasVisibility,
  }) {
    final cs = colorScheme;
    final location = event.location?.trim();
    final hostEmail = event.user?.email ?? '';
    final hostAvatar = event.user?.avatarUrl?.trim();
    final hostDisplay = hostName ?? (hostEmail.isNotEmpty ? hostEmail : null);
    final description = event.description.trim();
    final commentsCount = event.comments?.length ?? 0;

    Widget hostSection() {
      if (event.user == null || hostDisplay == null) {
        return const SizedBox.shrink();
      }
      return _SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cs.primary.withOpacity(0.18),
              backgroundImage: hostAvatar != null && hostAvatar.isNotEmpty
                  ? NetworkImage(hostAvatar)
                  : null,
              child: (hostAvatar == null || hostAvatar.isEmpty)
                  ? Text(
                      (hostInitial ?? "?"),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hostDisplay,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (hostTag != null && hostTag.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "@${hostTag.trim()}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (hostEmail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FilledButton.tonalIcon(
                        onPressed: () => _contactHost(hostEmail),
                        icon: const Icon(Icons.email_outlined),
                        label: const Text("Contact host"),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final detailEntries = <Widget>[
      _DetailLine(
        icon: Icons.schedule_rounded,
        label: "Start",
        value: _formatDate(event.startTime),
      ),
      if (event.endTime != null)
        _DetailLine(
          icon: Icons.hourglass_bottom_rounded,
          label: "End",
          value: _formatDate(event.endTime),
        ),
      if (location != null && location.isNotEmpty)
        _DetailLine(
          icon: Icons.location_on_outlined,
          label: "Location",
          value: location,
          onTap: () => _openMaps(location),
        ),
    ];

    final detailColumn = <Widget>[];
    for (var i = 0; i < detailEntries.length; i++) {
      detailColumn.add(detailEntries[i]);
      if (i != detailEntries.length - 1) {
        detailColumn.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              thickness: 1,
              color: cs.outline.withOpacity(0.18),
            ),
          ),
        );
      }
    }

    final children = <Widget>[
      _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "NIGHT LOGISTICS",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 4,
                    fontFeatures: const [FontFeature.enable('smcp')],
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
            ),
            const SizedBox(height: 24),
            ...detailColumn,
          ],
        ),
      ),
    ];

    final hostCard = hostSection();
    if (hostCard is! SizedBox) {
      children.add(const SizedBox(height: 20));
      children.add(hostCard);
    }

    children.addAll([
      const SizedBox(height: 20),
      _SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              icon: Icons.description_outlined,
              label: "About this event",
              color: cs.primary,
              trailing: commentsCount > 0
                  ? "$commentsCount ${commentsCount == 1 ? "comment" : "comments"}"
                  : null,
            ),
            const SizedBox(height: 16),
            if (description.isNotEmpty)
              _ExpandableDescription(
                text: description,
                content: _maybeRenderYouTube(description),
              )
            else
              Text(
                "No description provided yet.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openComments(event),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text("View comments"),
              ),
            ),
          ],
        ),
      ),
    ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  Widget _buildGuestsTab({
    required BuildContext context,
    required Event event,
    required ColorScheme colorScheme,
    required List<EventParticipation> participations,
    required List<EventParticipation> displayParticipations,
    required int remainingCount,
    required String? selectedStatus,
    required _RsvpOption? summaryOption,
  }) {
    final cs = colorScheme;
    final statusCounts = <String, int>{};
    for (final part in participations) {
      final normalized = _normalizeStatus(part.rsvpStatus) ?? 'pending';
      statusCounts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
    }

    String nameFor(EventParticipation p) {
      final user = p.user;
      if (user == null) return "Guest";
      final username = user.username?.trim();
      if (username != null && username.isNotEmpty) return username;
      final fullName = [
        user.firstName?.trim(),
        user.lastName?.trim(),
      ].whereType<String>().where((e) => e.isNotEmpty).join(" ");
      if (fullName.isNotEmpty) return fullName;
      if (user.email.isNotEmpty) return user.email;
      return "Guest";
    }

    Widget statusBadge(String status) {
      final opt = _optionFor(status);
      final color = opt?.color ?? cs.onSurfaceVariant;
      final label = opt?.label ?? _rsvpLabel(status);
      final icon = opt?.icon ?? Icons.help_outline_rounded;
      return _InfoBadge(
        icon: icon,
        label: "$label (${statusCounts[status] ?? 0})",
        color: color,
      );
    }

    Widget guestTile(EventParticipation p) {
      final status = _normalizeStatus(p.rsvpStatus) ?? p.rsvpStatus;
      final opt = _optionFor(status);
      final badgeColor = opt?.color ?? cs.onSurfaceVariant;
      final label = opt?.label ?? _rsvpLabel(status);
      final user = p.user;
      final avatarUrl = user?.avatarUrl?.trim();
      final displayName = nameFor(p);
      final subtitle = user?.tag?.trim().isNotEmpty == true
          ? "@${user!.tag!.trim()}"
          : (user?.email.isNotEmpty == true ? user!.email : null);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: cs.primary.withOpacity(0.15),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    }

    final children = <Widget>[];

    children.add(
      _buildRsvpSection(
        context: context,
        event: event,
        colorScheme: cs,
        selectedStatus: selectedStatus,
        summaryOption: summaryOption,
      ),
    );
    children.add(const SizedBox(height: 20));

    if (summaryOption != null || selectedStatus != null) {
      children.addAll([
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.person_pin_circle_rounded,
                label: "Your status",
                color: cs.primary,
                trailing:
                    summaryOption?.label ??
                    (selectedStatus != null
                        ? _rsvpLabel(selectedStatus)
                        : null),
              ),
              const SizedBox(height: 12),
              Text(
                "Update your RSVP from the Overview tab anytime.",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ]);
    }

    if (participations.isNotEmpty) {
      children.add(
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.group_rounded,
                label: "Guests",
                color: cs.secondary,
                trailing: "${participations.length} total",
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: statusCounts.keys.map(statusBadge).toList(),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < displayParticipations.length; i++) ...[
                if (i > 0) const Divider(height: 20, thickness: 0.4),
                guestTile(displayParticipations[i]),
              ],
              if (remainingCount > 0) ...[
                const SizedBox(height: 16),
                Text(
                  "+$remainingCount more ${remainingCount == 1 ? "guest" : "guests"}",
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      children.add(
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.group_off_rounded,
                label: "Guests",
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                "No guests yet. Be the first to RSVP!",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  Widget _buildMediaTab({
    required BuildContext context,
    required Event event,
    required ColorScheme colorScheme,
    required bool canUpload,
  }) {
    final cs = colorScheme;
    final files = event.files ?? const <EventFile>[];
    final children = <Widget>[];

    if (canUpload) {
      children.add(
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.file_upload_rounded,
                label: "Share attachments",
                color: cs.primary,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _uploadingMedia
                    ? null
                    : () => _pickAndUploadMedia(event),
                icon: const Icon(Icons.cloud_upload_rounded),
                label: Text(_uploadingMedia ? "Uploading…" : "Upload files"),
              ),
              const SizedBox(height: 12),
              Text(
                "Accepted guests can share media with everyone in the event.",
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_uploadingMedia) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 20));
    }

    if (files.isEmpty) {
      children.add(
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.perm_media_rounded,
                label: "Attachments",
                color: cs.secondary,
              ),
              const SizedBox(height: 12),
              Text(
                canUpload
                    ? "No files yet. Add your first attachment."
                    : "No files have been shared for this event.",
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    } else {
      children.add(
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.perm_media_rounded,
                label: "Attachments",
                color: cs.secondary,
                trailing: "${files.length}",
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < files.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final file = files[i];
                    return _MediaTile(
                      file: file,
                      colorScheme: cs,
                      onOpen: () {
                        if (file.isImage) {
                          _openImage(file.url);
                        } else if (file.isPdf) {
                          _openPdf(file.url);
                        } else {
                          _openExternal(file.url);
                        }
                      },
                      onDelete: canUpload
                          ? () => _deleteMediaFile(event, file.signedId)
                          : null,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      physics: const BouncingScrollPhysics(),
      children: children,
    );
  }

  String? _currentRsvpFor(Event event) {
    final status = _participationFor(event)?.rsvpStatus;
    if (status == null || status.isEmpty) return null;
    final normalized = _normalizeStatus(status);
    if (normalized == null || normalized == 'pending') return null;
    return normalized;
  }

  _RsvpOption? _optionFor(String status) {
    final normalized = _normalizeStatus(status);
    if (normalized == null) return null;
    for (final opt in _rsvpOptions) {
      if (opt.value == normalized) return opt;
    }
    return null;
  }

  String? _normalizeStatus(String? raw) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    switch (value) {
      case 'accepted':
      case 'attending':
      case 'going':
        return 'accepted';
      case 'maybe':
      case 'tentative':
        return 'maybe';
      case 'declined':
      case 'not_going':
      case 'cant_go':
        return 'declined';
      case 'pending':
      case '':
        return 'pending';
      default:
        return value;
    }
  }

  String _rsvpLabel(String status) {
    return _optionFor(status)?.label ?? status;
  }

  Future<void> _handleRsvpTap(Event event, String status) async {
    if (_rsvpLoading) return;
    final current = _currentRsvpFor(event);
    if (_pendingRsvp == null && current == status) return;

    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

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
          final targetOffset = previousOffset.clamp(0.0, maxScroll);
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
    BuildContext context,
    Event event,
    _RsvpOption option,
    String? selected,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = selected == option.value;
    final disabled = _rsvpLoading;

    final background = isSelected
        ? option.color.withOpacity(0.18)
        : cs.surface.withOpacity(0.35);
    final borderColor = isSelected ? option.color : cs.outline.withOpacity(0.4);
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
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
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
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _maybeRenderYouTube(String text) {
    final ytRegex = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([A-Za-z0-9_-]{11})',
    );
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

  void _openComments(Event event) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventCommentsScreen(
          event: event,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
    if (shouldRefresh == true && mounted) {
      setState(() {
        _eventFuture = _repo.fetchEvent(context, widget.event.id);
      });
    }
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
          final remainingCount = participations.length > 8
              ? participations.length - 8
              : 0;
          final selectedStatus = _pendingRsvp ?? _currentRsvpFor(e);
          final summaryOption = selectedStatus != null
              ? _optionFor(selectedStatus)
              : null;
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

          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
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
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        color: cs.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TabBar(
                          indicatorColor: cs.primary,
                          labelColor: cs.onSurface,
                          unselectedLabelColor: cs.onSurfaceVariant,
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Guests'),
                            Tab(text: 'Media'),
                          ],
                        ),
                      ),
                    ),
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
                ];
              },
              body: TabBarView(
                physics: const ClampingScrollPhysics(),
                children: [
                  _buildOverviewTab(
                    context: context,
                    event: e,
                    colorScheme: cs,
                    hostName: hostName,
                    hostInitial: hostInitial,
                    hostTag: hostTag,
                    categoryLabel: categoryLabel,
                    hasCategory: hasCategory,
                    visibilityLabel: visibilityLabel,
                    hasVisibility: hasVisibility,
                  ),
                  _buildGuestsTab(
                    context: context,
                    event: e,
                    colorScheme: cs,
                    participations: participations,
                    displayParticipations: displayParticipations,
                    remainingCount: remainingCount,
                    selectedStatus: selectedStatus,
                    summaryOption: summaryOption,
                  ),
                  _buildMediaTab(
                    context: context,
                    event: e,
                    colorScheme: cs,
                    canUpload: _canUploadMedia(e),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
