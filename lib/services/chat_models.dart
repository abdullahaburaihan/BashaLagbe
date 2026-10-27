import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a 1-to-1 conversation between a landlord and a tenant
/// tied directly to an accepted rental request.
class Conversation {
  const Conversation({
    required this.id,
    required this.requestId,
    required this.propertyId,
    required this.propertyTitle,
    required this.ownerId,
    required this.tenantId,
    required this.tenantName,
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String requestId;
  final String propertyId;
  final String propertyTitle;
  final String ownerId;
  final String tenantId;
  final String tenantName;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return Conversation(
      id: id,
      requestId: data['requestId'] as String? ?? id,
      propertyId: data['propertyId'] as String? ?? '',
      propertyTitle: data['propertyTitle'] as String? ?? 'Rental Property',
      ownerId: data['ownerId'] as String? ?? '',
      tenantId: data['tenantId'] as String? ?? '',
      tenantName: data['tenantName'] as String? ?? 'Tenant',
      lastMessageText: data['lastMessageText'] as String?,
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      lastMessageAt: parseNullableTime(data['lastMessageAt']),
      createdAt: parseTime(data['createdAt']),
      updatedAt: parseTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'propertyId': propertyId,
      'propertyTitle': propertyTitle,
      'ownerId': ownerId,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper to determine the display title for a participant
  String getOtherParticipantRole(String currentUserId) {
    if (currentUserId == ownerId) {
      return 'Tenant ($tenantName)';
    } else {
      return 'Landlord';
    }
  }
}

/// Represents a single immutable chat message in a conversation.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime parseTime(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return ChatMessage(
      id: id,
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: parseTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

