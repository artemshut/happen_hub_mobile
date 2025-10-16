import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment.dart';
import '../models/event.dart';
import '../repositories/comment_repository.dart';

class EventCommentsScreen extends StatefulWidget {
  final Event event;
  final String currentUserId;

  const EventCommentsScreen({
    super.key,
    required this.event,
    required this.currentUserId,
  });

  @override
  State<EventCommentsScreen> createState() => _EventCommentsScreenState();
}

class _EventCommentsScreenState extends State<EventCommentsScreen> {
  final CommentRepository _repository = CommentRepository();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _comments = List<Comment>.from(widget.event.comments ?? const []);
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final fetched = await _repository.fetchComments(widget.event.id);
      if (!mounted) return;
      setState(() {
        _comments = fetched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load comments: $e")),
      );
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final created = await _repository.createComment(widget.event.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, created];
        _controller.clear();
      });
      await Future.delayed(const Duration(milliseconds: 100));
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send message: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final cs = Theme.of(ctx).colorScheme;
            return AlertDialog(
              title: const Text("Delete message?"),
              content:
                  const Text("This message will be removed for everyone."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Delete"),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _deletingId = comment.id);
    try {
      await _repository.deleteComment(widget.event.id, comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _deletingId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message deleted")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete message: $e")),
      );
    }
  }

  bool _canDelete(Comment comment) {
    return comment.user?.id == widget.currentUserId ||
        widget.event.user?.id == widget.currentUserId;
  }

  String _senderName(Comment comment) {
    final user = comment.user;
    if (user == null) return "Member";

    final fullName = [
      user.firstName?.trim(),
      user.lastName?.trim(),
    ].whereType<String>().where((p) => p.isNotEmpty).join(" ");
    if (fullName.isNotEmpty) return fullName;

    final username = user.username?.trim();
    if (username != null && username.isNotEmpty) return username;

    return user.email;
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return "";
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final formatter =
        sameDay ? DateFormat("HH:mm") : DateFormat("MMM d • HH:mm");
    return formatter.format(local);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          "No messages yet.\nSay hi to start the chat!",
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _ChatBubble(
                            comment: comment,
                            isMine: comment.user?.id == widget.currentUserId,
                            canDelete: _canDelete(comment),
                            deleting: _deletingId == comment.id,
                            onDelete: () => _deleteComment(comment),
                            senderName: _senderName(comment),
                            timestamp: _formatTimestamp(comment.createdAt),
                          );
                        },
                      ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _ComposerBar(
                controller: _controller,
                sending: _sending,
                onSend: _sendComment,
                enabled: widget.currentUserId.isNotEmpty,
                colorScheme: cs,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final bool enabled;
  final ColorScheme colorScheme;

  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.enabled,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled && !sending,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              isDense: true,
              hintText: enabled
                  ? "Message fellow guests..."
                  : "Sign in to join the chat",
              filled: true,
              fillColor: colorScheme.surfaceVariant.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
          ),
        ),
        const SizedBox(width: 12),
        sending
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : IconButton(
                onPressed: enabled ? onSend : null,
                icon: Icon(
                  Icons.send_rounded,
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final bool canDelete;
  final bool deleting;
  final VoidCallback onDelete;
  final String senderName;
  final String timestamp;

  const _ChatBubble({
    required this.comment,
    required this.isMine,
    required this.canDelete,
    required this.deleting,
    required this.onDelete,
    required this.senderName,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bubbleColor =
        isMine ? cs.primary.withOpacity(0.85) : cs.surfaceVariant.withOpacity(0.7);
    final textColor = isMine ? cs.onPrimary : cs.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 4,
              ),
              child: Text(
                senderName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
            Material(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onLongPress: canDelete ? onDelete : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.content,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: textColor),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timestamp,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 6),
                            deleting
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white70,
                                    ),
                                  )
                                : IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints.tightFor(
                                      width: 20,
                                      height: 20,
                                    ),
                                    splashRadius: 16,
                                    iconSize: 16,
                                    onPressed: onDelete,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
