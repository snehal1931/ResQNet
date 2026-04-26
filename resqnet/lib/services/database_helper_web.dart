import '../models/message.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  final List<SosMessage> _messages = [];
  final List<ChatMessage> _chats = [];

  Future<void> insertMessage(SosMessage message) async {
    final index = _messages.indexWhere((m) => m.messageId == message.messageId);
    if (index == -1) {
      _messages.add(message);
    } else {
      _messages[index] = message;
    }
  }

  Future<void> updateMessageStatus(String messageId, String newStatus) async {
    final index = _messages.indexWhere((m) => m.messageId == messageId);
    if (index != -1) {
      final msg = _messages[index];
      _messages[index] = SosMessage(
        messageId: msg.messageId,
        senderId: msg.senderId,
        timestamp: msg.timestamp,
        content: msg.content,
        headcount: msg.headcount,
        severity: msg.severity,
        status: newStatus,
        hopCount: msg.hopCount,
        latitude: msg.latitude,
        longitude: msg.longitude,
        rescuerLatitude: msg.rescuerLatitude,
        rescuerLongitude: msg.rescuerLongitude,
      );
    }
  }

  Future<List<SosMessage>> getMessages() async {
    final sorted = List<SosMessage>.from(_messages);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  Future<bool> messageExists(String messageId) async {
    return _messages.any((m) => m.messageId == messageId);
  }

  Future<void> insertChatMessage(ChatMessage message) async {
    _chats.add(message);
  }

  Future<List<ChatMessage>> getChatMessages(String sosId, String localNodeId) async {
    // Note: returning copies or creating ChatMessage objects from internal state
    return _chats.where((c) => c.sosId == sosId).toList();
  }
}
