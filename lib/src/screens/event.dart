import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_iframe/flutter_html_iframe.dart'; // 👈 for video/music embeds
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../models/event.dart';
import '../repositories/event_repository.dart';

class EventScreen extends StatefulWidget {
  final Event event;

  const EventScreen({super.key, required this.event});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final EventRepository _repo = EventRepository();
  late Future<Event> _eventFuture;

  @override
  void initState() {
    super.initState();
    _eventFuture = _repo.fetchEvent(context, widget.event.id);
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

  /// --- HTML sanitization + embeds ---
  String sanitizeHtml(String rawHtml) {
    String processed = rawHtml;

    // 🎥 YouTube
    final ytRegex = RegExp(
        r'(https?:\/\/)?(www\.)?(youtube\.com\/watch\?v=|youtu\.be\/)([^\s]+)');
    processed = processed.replaceAllMapped(ytRegex, (m) {
      final videoId = m.group(4);
      return '''
        <iframe width="100%" height="200"
          src="https://www.youtube.com/embed/$videoId"
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen></iframe>
      ''';
    });

    // 🎬 Vimeo
    final vimeoRegex = RegExp(r'(https?:\/\/)?(www\.)?vimeo\.com\/(\d+)');
    processed = processed.replaceAllMapped(vimeoRegex, (m) {
      final id = m.group(3);
      return '''
        <iframe src="https://player.vimeo.com/video/$id"
          width="100%" height="200" frameborder="0"
          allow="autoplay; fullscreen; picture-in-picture" allowfullscreen>
        </iframe>
      ''';
    });

    // 🎵 Spotify
    final spotifyRegex = RegExp(r'(https?:\/\/open\.spotify\.com\/[^\s]+)');
    processed = processed.replaceAllMapped(spotifyRegex, (m) {
      final link = m.group(1)!;
      final embed = link.replaceFirst("open.spotify.com", "open.spotify.com/embed");
      return '''
        <iframe src="$embed" width="100%" height="152" frameborder="0"
          allowtransparency="true" allow="encrypted-media"></iframe>
      ''';
    });

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
      ),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (e.coverImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(e.coverImageUrl!),
                  ),
                const SizedBox(height: 16),

                Text(
                  e.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
                const SizedBox(height: 8),

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

                // ✅ Description with embeds
                Html(
                  data: sanitizeHtml(e.description),
                  style: {
                    "body": Style(
                      fontSize: FontSize(16),
                      color: cs.onSurface,
                    ),
                  },
                  extensions: const [
                    IframeHtmlExtension(), // 🎥 Support YouTube/Vimeo/Spotify
                  ],
                  onLinkTap: (url, _, __) {
                    if (url != null) _openLink(url);
                  },
                ),

                const SizedBox(height: 24),

                // ✅ Files section
                if (e.files != null && e.files!.isNotEmpty) ...[
                  Text(
                    "Files",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
          );
        },
      ),
    );
  }
}