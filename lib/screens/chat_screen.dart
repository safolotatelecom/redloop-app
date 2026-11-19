import 'dart:async';

import 'package:flutter/material.dart';

import '../api_helper.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String donorId;
  final String otherName;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.donorId,
    required this.otherName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const Color primary = Color(0xFFDC2638);

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];

  Timer? _refreshTimer;

  String? _currentUserId;
  String? _expiresAt;

  bool _loading = true;
  bool _sending = false;
  bool _chatExpired = false;
  String? _error;

  String get _endpoint =>
      '/blood-requests/${Uri.encodeComponent(widget.requestId)}/messages';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_sending && !_loading) {
          _loadMessages(showLoader: false);
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final result = await ApiService.getCurrentUser();

    if (!mounted || result['success'] != true) return;

    final user = result['user'];

    if (user is Map) {
      setState(() {
        _currentUserId = user['id']?.toString();
      });
    }
  }

  List<Map<String, dynamic>> _extractMessages(
    Map<String, dynamic> result,
  ) {
    dynamic value = result['messages'] ?? result['data'];

    if (value is Map) {
      value = value['messages'] ?? value['data'];
    }

    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();
  }

  Future<void> _loadMessages({
    bool showLoader = true,
  }) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await ApiService.get(
        _endpoint,
        query: {
          'donor_id': widget.donorId,
        },
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final messages = _extractMessages(result);

        final expiry = result['chat_expires_at'] ??
            result['expires_at'];

        final expired = result['chat_expired'] == true ||
            result['expired'] == true;

        setState(() {
          _messages = messages;
          _expiresAt = expiry?.toString();
          _chatExpired = expired || _isExpired(_expiresAt);
          _loading = false;
          _error = null;
        });

        _scrollToBottom();
      } else {
        setState(() {
          _loading = false;
          _error = result['message']?.toString() ??
              'মেসেজ লোড করা যায়নি।';
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'সার্ভারের সঙ্গে যোগাযোগ করা যাচ্ছে না।';
      });
    }
  }

  bool _isExpired(String? value) {
    if (value == null || value.isEmpty) return false;

    try {
      final expiry = DateTime.parse(value).toLocal();
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  bool _isMine(Map<String, dynamic> message) {
    final senderId = message['sender_id']?.toString();

    if (_currentUserId == null || senderId == null) {
      return false;
    }

    return senderId == _currentUserId;
  }

  String _messageText(Map<String, dynamic> message) {
    return message['message']?.toString() ??
        message['body']?.toString() ??
        '';
  }

  String _messageTime(Map<String, dynamic> message) {
    final value = message['created_at']?.toString();

    if (value == null || value.isEmpty) return '';

    try {
      final date = DateTime.parse(value).toLocal();
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _sending || _chatExpired) return;

    FocusScope.of(context).unfocus();

    setState(() => _sending = true);

    try {
      final result = await ApiService.post(
        _endpoint,
        body: {
          'donor_id': widget.donorId,
          'message': message,
        },
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _messageController.clear();

        await _loadMessages(showLoader: false);
      } else {
        final statusCode = result['status_code'];

        if (statusCode == 403 || statusCode == 410) {
          setState(() => _chatExpired = true);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ??
                  'মেসেজ পাঠানো যায়নি।',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('মেসেজ পাঠানো যায়নি। আবার চেষ্টা করুন।'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Widget _buildMessage(
    Map<String, dynamic> message,
  ) {
    final mine = _isMine(message);
    final content = _messageText(message);

    return Align(
      alignment:
          mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: mine ? primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine
              ? null
              : Border.all(color: const Color(0xFFE8E8ED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              content,
              style: TextStyle(
                color: mine ? Colors.white : const Color(0xFF252832),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _messageTime(message),
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? Colors.white70
                    : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    if (_chatExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        color: Colors.grey.shade100,
        child: const Text(
          'এই চ্যাটের সময়সীমা শেষ হয়েছে। এখন আর মেসেজ পাঠানো যাবে না।',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFEAEAF0)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'মেসেজ লিখুন...',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F8),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _sendMessage,
              style: IconButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade400,
              ),
              icon: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF20232B),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'RedLoop Pro • ব্যক্তিগত চ্যাট',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadMessages(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: primary,
                    ),
                  )
                : _error != null && _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _loadMessages(),
                                child: const Text('আবার চেষ্টা করুন'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text(
                              'এখনো কোনো মেসেজ নেই।\nকথা শুরু করুন।',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                height: 1.6,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessage(_messages[index]);
                            },
                          ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}
