class SosMessage {
  final String messageId;
  final String senderId;
  final int timestamp;
  final String content;
  final int headcount;
  final String severity; // CRITICAL, HIGH, LOW
  final String status;   // PENDING, RESCUING, RESOLVED
  final int hopCount;
  final double? latitude;
  final double? longitude;
  final double? rescuerLatitude;
  final double? rescuerLongitude;
  
  SosMessage({
    required this.messageId,
    required this.senderId,
    required this.timestamp,
    required this.content,
    required this.headcount,
    required this.severity,
    this.status = 'PENDING',
    this.hopCount = 0,
    this.latitude,
    this.longitude,
    this.rescuerLatitude,
    this.rescuerLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'timestamp': timestamp,
      'content': content,
      'headcount': headcount,
      'severity': severity,
      'status': status,
      'hopCount': hopCount,
      'latitude': latitude,
      'longitude': longitude,
      'rescuerLatitude': rescuerLatitude,
      'rescuerLongitude': rescuerLongitude,
    };
  }

  factory SosMessage.fromMap(Map<String, dynamic> map) {
    return SosMessage(
      messageId: map['messageId'],
      senderId: map['senderId'],
      timestamp: map['timestamp'],
      content: map['content'],
      headcount: map['headcount'],
      severity: map['severity'],
      status: map['status'] ?? 'PENDING',
      hopCount: map['hopCount'] ?? 0,
      latitude: map['latitude'],
      longitude: map['longitude'],
      rescuerLatitude: map['rescuerLatitude'],
      rescuerLongitude: map['rescuerLongitude'],
    );
  }
}
