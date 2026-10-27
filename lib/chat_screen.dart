import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/services/firestore_service.dart';

/// Real-time chat screen between landlord and tenant.
///
/// Message transmission and access are strictly governed by Cloud Firestore security rules
/// which verify that the underlying rental request is in the 'accepted' status.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    this.currentUser,
    this.firestoreService,
  });

  final Conversation conversation;
  final User? currentUser;
  final FirestoreService? firestoreService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  FirestoreService get _service => widget.firestoreService ?? FirestoreService.instance;
  User? get _user => widget.currentUser ?? FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage() async {
    final user = _user;
    if (user == null) return;

    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message cannot exceed 2000 characters.'),
          backgroundColor: AppColors.heart,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await _service.sendMessage(
        conversationId: widget.conversation.id,
        senderId: user.uid,
        text: text,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        // Restore unsent text
        _textController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.heart,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final currentUid = user?.uid ?? '';
    final otherRole = widget.conversation.getOtherParticipantRole(currentUid);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.conversation.propertyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              otherRole,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat history stream
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _service.streamMessages(widget.conversation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Error loading conversation:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: AppColors.lightGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Start the Conversation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Rental request accepted! Coordinate your move-in date, key handover, or ask any remaining questions here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Auto scroll on new messages
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == currentUid;
                      return _buildMessageBubble(msg, isMe);
                    },
                  );
                },
              ),
            ),

            // Message Composer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      minLines: 1,
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSending)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton.filled(
                      onPressed: _handleSendMessage,
                      icon: const Icon(Icons.send, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe) {
    final timeStr = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppColors.green : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.textDark,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

