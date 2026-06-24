class SosMessage {
  final String messageId;
  final String senderId;
  final int timestamp;
  final String content;
  final int headcount;
  final String severity; // CRITICAL, HIGH, MEDIUM, LOW
  final String status;   // PENDING, RESCUING, RESOLVED
  final int hopCount;
  final double? latitude;
  final double? longitude;
  final double? rescuerLatitude;
  final double? rescuerLongitude;
  
  // Multi-modal AI prioritisation fields
  final String disasterType;
  final String injurySeverity;
  final double priorityScore;
  final String priorityExplanation;
  final double confidenceScore;
  
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
    this.disasterType = 'Other',
    this.injurySeverity = 'Low',
    this.priorityScore = 0.0,
    this.priorityExplanation = '[]',
    this.confidenceScore = 0.0,
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
      'disasterType': disasterType,
      'injurySeverity': injurySeverity,
      'priorityScore': priorityScore,
      'priorityExplanation': priorityExplanation,
      'confidenceScore': confidenceScore,
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
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      rescuerLatitude: map['rescuerLatitude'] != null ? (map['rescuerLatitude'] as num).toDouble() : null,
      rescuerLongitude: map['rescuerLongitude'] != null ? (map['rescuerLongitude'] as num).toDouble() : null,
      disasterType: map['disasterType'] ?? 'Other',
      injurySeverity: map['injurySeverity'] ?? 'Low',
      priorityScore: map['priorityScore'] != null ? (map['priorityScore'] as num).toDouble() : 0.0,
      priorityExplanation: map['priorityExplanation'] ?? '[]',
      confidenceScore: map['confidenceScore'] != null ? (map['confidenceScore'] as num).toDouble() : 0.0,
    );
  }
}

