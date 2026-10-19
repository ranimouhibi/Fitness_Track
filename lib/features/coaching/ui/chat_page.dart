import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/session_service.dart';
import '../data/coach_booking_repository.dart';

class ChatPage extends ConsumerStatefulWidget {
  final int bookingId;

  const ChatPage({super.key, required this.bookingId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _repository = CoachBookingRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, Object?>> _messages = [];
  Timer? _refreshTimer;
  bool _loading = true;
  bool _sending = false;
  bool _closed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final participant = ref.read(sessionProvider);
    if (participant == null) {
      if (mounted) {
        setState(() {
          _closed = true;
          _loading = false;
          _error = 'Sign in to access this chat.';
        });
      }
      return;
    }
    try {
      final messages = await _repository.messagesForBooking(
        bookingId: widget.bookingId,
        participantId: participant.id,
      );
      if (!mounted) return;
      final shouldScroll = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _closed = false;
        _loading = false;
        _error = null;
      });
      if (shouldScroll) _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      final accessClosed = error is StateError;
      setState(() {
        _closed = accessClosed;
        _loading = false;
        _error = accessClosed
            ? error.message.toString()
            : 'Could not refresh messages. Check your connection and retry.';
      });
    }
  }

  Future<void> _send() async {
    final participant = ref.read(sessionProvider);
    if (participant == null || _sending || _closed) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repository.sendMessage(
        bookingId: widget.bookingId,
        senderId: participant.id,
        body: text,
      );
      if (!mounted) return;
      _messageController.clear();
      await _loadMessages();
    } catch (error) {
      if (!mounted) return;
      if (error is StateError) {
        setState(() {
          _closed = true;
          _error = error.message.toString();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final participant = ref.watch(sessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Booking chat')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _closed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          _error ?? 'This booking chat is no longer available.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _loadMessages,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
              : Column(
                  children: [
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text('Chat is open. Send the first message.'),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isMine =
                                    message['sender_id'] == participant?.id;
                                final time = DateTime.tryParse(
                                  message['sent_at'] as String,
                                );
                                return Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(context).width * 0.78,
                                    ),
                                    child: Card(
                                      color: isMine
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                          : null,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (!isMine)
                                              Text(
                                                '${message['first_name']} ${message['last_name']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelMedium,
                                              ),
                                            Text(message['body'] as String),
                                            if (time != null)
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  DateFormat.jm().format(time),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _send(),
                                decoration: const InputDecoration(
                                  hintText: 'Write a message',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: 'Send message',
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
