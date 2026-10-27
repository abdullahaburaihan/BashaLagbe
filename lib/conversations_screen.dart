import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:basha_lagbe/main.dart';
import 'package:basha_lagbe/services/firestore_service.dart';
import 'package:basha_lagbe/chat_screen.dart';

/// Screen listing all real-time conversations for the authenticated user.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({
    super.key,
    this.currentUser,
    this.firestoreService,
  });

  final User? currentUser;
  final FirestoreService? firestoreService;

  FirestoreService get _service => firestoreService ?? FirestoreService.instance;
  User? get _user => currentUser ?? FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(
          child: Text('Please sign in to view your messages.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: AppColors.green),
            SizedBox(width: 8),
            Text('Messages'),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _service.streamUserConversations(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error loading conversations:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }

          final conversations = snapshot.data ?? [];
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.lightGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        size: 56,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Messages Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When a landlord accepts your rental request, an in-app chat is automatically unlocked so you can coordinate with each other.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _buildConversationCard(context, conv, user.uid);
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationCard(BuildContext context, Conversation conv, String currentUid) {
    final otherRole = conv.getOtherParticipantRole(currentUid);
    final lastSnippet = conv.lastMessageText ?? 'Rental request accepted. Tap to chat.';
    final timeStr = conv.lastMessageAt != null
        ? '${conv.lastMessageAt!.hour.toString().padLeft(2, '0')}:${conv.lastMessageAt!.minute.toString().padLeft(2, '0')}'
        : '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversation: conv,
                currentUser: _user,
                firestoreService: _service,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: AppColors.darkGreen, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.propertyTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      otherRole,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastSnippet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

