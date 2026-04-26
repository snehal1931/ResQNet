class ChatMessage {
  final String messageId;
  final String senderId;
  final String receiverId; // nodeId of the other party
  final String sosId;      // The SOS event this chat belongs to
  final String content;
  final String? imagePath; // Local path to the image
  final String? audioPath; // Local path to the audio file
  final int timestamp;
  final bool isMe;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.sosId,
    required this.content,
    this.imagePath,
    this.audioPath,
    required this.timestamp,
    this.isMe = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'sosId': sosId,
      'content': content,
      'imagePath': imagePath,
      'audioPath': audioPath,
      'timestamp': timestamp,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String localNodeId) {
    return ChatMessage(
      messageId: map['messageId'],
      senderId: map['senderId'],
      receiverId: map['receiverId'],
      sosId: map['sosId'],
      content: map['content'],
      imagePath: map['imagePath'],
      audioPath: map['audioPath'],
      timestamp: map['timestamp'],
      isMe: map['senderId'] == localNodeId,
    );
  }
}
