import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/message.dart';
import '../models/chat_message.dart';
import 'database_helper.dart';

// Shield native-only imports
import 'dart:io' if (dart.library.html) 'package:resqnet/services/web_stubs.dart' as io;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MeshService {
  final String nodeId;
  final DatabaseHelper dbHelper = DatabaseHelper();
  final Strategy strategy = Strategy.P2P_CLUSTER;
  static const String serviceId = "com.resqnet.emergency_mesh";

  // List of currently connected peers
  final List<String> connectedEndpoints = [];
  Function(SosMessage)? onMessageReceived;
  Function(ChatMessage)? onChatReceived;
  
  // Maps filePayloadId to temporary local path
  final Map<int, String> _incomingFiles = {};

  Timer? _simulatorTimer;

  MeshService(this.nodeId) {
    startSimulatorSync();
  }

  bool get _isSupported {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
  }

  Future<void> requestPermissions() async {
    if (!_isSupported) {
      print(
        "MeshService: Running on unsupported platform. Simulating permissions.",
      );
      return;
    }

    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.nearbyWifiDevices,
    ].request();

    if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      print("MeshService: Some permissions were denied. Mesh networking might fail.");
    } else {
      print("MeshService: All permissions granted.");
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("MeshService: GPS is OFF! Nearby Connections will fail. Please turn on Location in Quick Settings.");
      }
    } catch (e) {
      print("MeshService: Error checking location services: $e");
    }
  }

  // Victim Mode or Relay Node advertising itself
  Future<void> startAdvertising() async {
    if (!_isSupported) {
      print("MeshService: Simulating Start Advertising as $nodeId");
      return;
    }
    try {
      await Nearby().startAdvertising(
        nodeId,
        strategy,
        serviceId: serviceId,
        onConnectionInitiated: (id, info) async {
          // Auto-accept connection
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (payload.type == PayloadType.BYTES) {
                _handleIncomingBytePayload(endpointId, payload.bytes!);
              } else if (payload.type == PayloadType.FILE) {
                _handleIncomingFilePayload(endpointId, payload);
              }
            },
            onPayloadTransferUpdate: (eptId, payloadTransferUpdate) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            connectedEndpoints.add(id);
            // Sync messages to the newly connected peer
            syncWithPeer(id);
          }
        },
        onDisconnected: (id) {
          connectedEndpoints.remove(id);
        },
      );
      print("Started advertising as $nodeId");
    } catch (e) {
      print("Failed to start advertising: $e");
    }
  }

  // Rescuer Mode or Relay Node discovering others
  Future<void> startDiscovery() async {
    if (!_isSupported) {
      print("MeshService: Simulating Start Discovery...");
      return;
    }
    try {
      await Nearby().startDiscovery(
        nodeId,
        strategy,
        serviceId: serviceId,
        onEndpointFound: (id, name, sId) async {
          // Request connection to the found endpoint
          await Nearby().requestConnection(
            nodeId,
            id,
            onConnectionInitiated: (id, info) async {
              await Nearby().acceptConnection(
                id,
                onPayLoadRecieved: (endpointId, payload) {
                  if (payload.type == PayloadType.BYTES) {
                    _handleIncomingBytePayload(endpointId, payload.bytes!);
                  } else if (payload.type == PayloadType.FILE) {
                    _handleIncomingFilePayload(endpointId, payload);
                  }
                },
                onPayloadTransferUpdate: (eptId, payloadTransferUpdate) {},
              );
            },
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                connectedEndpoints.add(id);
                // Sync messages to the newly connected peer
                syncWithPeer(id);
              }
            },
            onDisconnected: (id) {
              connectedEndpoints.remove(id);
            },
          );
        },
        onEndpointLost: (id) {
          print("Lost endpoint: $id");
        },
      );
      print("Started discovering networks...");
    } catch (e) {
      print("Failed to start discovery: $e");
    }
  }

  void _handleIncomingBytePayload(
    String sourceEndpoint,
    List<int> bytes,
  ) async {
    try {
      final jsonStr = utf8.decode(bytes);
      final msgMap = jsonDecode(jsonStr);
      
      if (msgMap.containsKey('sosId')) {
        // Handle ChatMessage
        final chatMsg = ChatMessage.fromMap(msgMap, nodeId);
        
        // Check if we already received the file for this message
        if (msgMap.containsKey('filePayloadId')) {
          int fileId = msgMap['filePayloadId'];
          if (_incomingFiles.containsKey(fileId)) {
            final linkedMsg = ChatMessage(
              messageId: chatMsg.messageId,
              senderId: chatMsg.senderId,
              receiverId: chatMsg.receiverId,
              sosId: chatMsg.sosId,
              content: chatMsg.content,
              imagePath: chatMsg.imagePath != null ? _incomingFiles[fileId] : null,
              audioPath: chatMsg.audioPath != null ? _incomingFiles[fileId] : null,
              timestamp: chatMsg.timestamp,
            );
            await dbHelper.insertChatMessage(linkedMsg);
            if (onChatReceived != null) onChatReceived!(linkedMsg);
            _incomingFiles.remove(fileId);
            _relayChatToPeers(linkedMsg, excludeEndpoint: sourceEndpoint);
            return;
          }
        }

        await dbHelper.insertChatMessage(chatMsg);
        if (onChatReceived != null) onChatReceived!(chatMsg);
        _relayChatToPeers(chatMsg, excludeEndpoint: sourceEndpoint);
      } else {
        // Handle SosMessage
        final msg = SosMessage.fromMap(msgMap);
        bool exists = await dbHelper.messageExists(msg.messageId);
        
        if (!exists) {
          await dbHelper.insertMessage(msg);
          if (onMessageReceived != null) onMessageReceived!(msg);
          _relayToPeers(msg, excludeEndpoint: sourceEndpoint);
        } else {
          final existingMsgs = await dbHelper.getMessages();
          final localMsg = existingMsgs.firstWhere((m) => m.messageId == msg.messageId);
          
          if (localMsg.status != msg.status || 
              localMsg.rescuerLatitude != msg.rescuerLatitude ||
              localMsg.rescuerLongitude != msg.rescuerLongitude) {
            await dbHelper.insertMessage(msg);
            if (onMessageReceived != null) onMessageReceived!(msg);
            _relayToPeers(msg, excludeEndpoint: sourceEndpoint);
          }
        }
      }
    } catch (e) {
      print("Error decoding payload: $e");
    }
  }

  void _handleIncomingFilePayload(String sourceEndpoint, Payload payload) async {
    if (payload.uri == null) return;

    try {
      final file = io.File(payload.uri!);
      final directory = await getApplicationDocumentsDirectory();
      final fileName = "resq_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final savedFile = await file.copy("${directory.path}/$fileName");

      print("File received and saved to: ${savedFile.path}");
      
      // Store in map so it can be linked when the ChatMessage metadata arrives
      _incomingFiles[payload.id] = savedFile.path;
      
      // Safety: clear old files after 5 minutes
      Future.delayed(const Duration(minutes: 5), () {
        _incomingFiles.remove(payload.id);
      });
    } catch (e) {
      print("Error handling incoming file: $e");
    }
  }

  Future<io.File?> compressImage(io.File file) async {
    if (kIsWeb) return null;
    final filePath = file.absolute.path;
    final lastIndex = filePath.lastIndexOf(RegExp(r'.png|.jp'));
    if (lastIndex == -1) return null;
    
    final outPath = "${filePath.substring(0, lastIndex)}_compressed.jpg";
    
    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path, 
      outPath,
      quality: 70,
      minWidth: 1024,
      minHeight: 1024,
    );

    return result != null ? io.File(result.path) : null;
  }

  Future<void> sendChatMessageWithImage(ChatMessage chatMessage, io.File imageFile) async {
    if (!_isSupported || kIsWeb) {
      print("MeshService: Simulating Chat with Image");
      await sendChatMessage(chatMessage);
      return;
    }

    // 1. Compress
    io.File? compressed = await compressImage(imageFile);
    io.File toSend = compressed ?? imageFile;

    // 2. Save locally
    final directory = await getApplicationDocumentsDirectory();
    final fileName = "sent_${chatMessage.messageId}.jpg";
    final savedFile = await toSend.copy("${directory.path}/$fileName");
    
    final updatedMsg = ChatMessage(
      messageId: chatMessage.messageId,
      senderId: chatMessage.senderId,
      receiverId: chatMessage.receiverId,
      sosId: chatMessage.sosId,
      content: chatMessage.content,
      imagePath: savedFile.path,
      timestamp: chatMessage.timestamp,
    );

    // 3. Save to DB
    await dbHelper.insertChatMessage(updatedMsg);

    for (String endpointId in connectedEndpoints) {
      // 4. Send File first to get payloadId (if needed)
      int filePayloadId = await Nearby().sendFilePayload(endpointId, savedFile.path);
      
      // 5. Send Metadata (Bytes) with an indication of the file payload ID
      final Map<String, dynamic> msgMap = updatedMsg.toMap();
      msgMap['filePayloadId'] = filePayloadId;
      
      final payloadBytes = utf8.encode(jsonEncode(msgMap));
      await Nearby().sendBytesPayload(endpointId, payloadBytes);
    }
  }

  Future<void> sendChatMessageWithAudio(ChatMessage chatMessage, io.File audioFile) async {
    if (!_isSupported || kIsWeb) {
      print("MeshService: Simulating Chat with Audio");
      await sendChatMessage(chatMessage);
      return;
    }

    // Save locally
    final directory = await getApplicationDocumentsDirectory();
    final fileName = "sent_audio_${chatMessage.messageId}.m4a";
    final savedFile = await audioFile.copy("${directory.path}/$fileName");
    
    final updatedMsg = ChatMessage(
      messageId: chatMessage.messageId,
      senderId: chatMessage.senderId,
      receiverId: chatMessage.receiverId,
      sosId: chatMessage.sosId,
      content: chatMessage.content,
      audioPath: savedFile.path,
      timestamp: chatMessage.timestamp,
    );

    await dbHelper.insertChatMessage(updatedMsg);

    for (String endpointId in connectedEndpoints) {
      int filePayloadId = await Nearby().sendFilePayload(endpointId, savedFile.path);
      
      final Map<String, dynamic> msgMap = updatedMsg.toMap();
      msgMap['filePayloadId'] = filePayloadId;
      
      final payloadBytes = utf8.encode(jsonEncode(msgMap));
      await Nearby().sendBytesPayload(endpointId, payloadBytes);
    }
  }

  Future<void> broadcastStatusUpdate(String messageId, String newStatus) async {
    final messages = await dbHelper.getMessages();
    try {
      final msg = messages.firstWhere((m) => m.messageId == messageId);
      final updatedMsg = SosMessage(
        messageId: msg.messageId,
        senderId: msg.senderId,
        timestamp: msg.timestamp,
        content: msg.content,
        headcount: msg.headcount,
        severity: msg.severity,
        status: newStatus,
        hopCount: msg.hopCount + 1,
        latitude: msg.latitude,
        longitude: msg.longitude,
        rescuerLatitude: msg.rescuerLatitude,
        rescuerLongitude: msg.rescuerLongitude,
      );
      
      await dbHelper.updateMessageStatus(messageId, newStatus);
      await broadcastMessage(updatedMsg);
    } catch (e) {
      print("Could not find message for status update: $e");
    }
  }

  Future<void> broadcastRescuerLocation(String messageId, double lat, double lng) async {
    final messages = await dbHelper.getMessages();
    try {
      final msg = messages.firstWhere((m) => m.messageId == messageId);
      final updatedMsg = SosMessage(
        messageId: msg.messageId,
        senderId: msg.senderId,
        timestamp: msg.timestamp,
        content: msg.content,
        headcount: msg.headcount,
        severity: msg.severity,
        status: msg.status,
        hopCount: msg.hopCount + 1,
        latitude: msg.latitude,
        longitude: msg.longitude,
        rescuerLatitude: lat,
        rescuerLongitude: lng,
      );
      
      await dbHelper.insertMessage(updatedMsg); // Overwrite with new location
      await broadcastMessage(updatedMsg);
    } catch (e) {
      print("Could not find message for location update: $e");
    }
  }

  Future<void> broadcastMessage(
    SosMessage message, {
    String? excludeEndpoint,
  }) async {
    _relayToPeers(message, excludeEndpoint: excludeEndpoint);
    await _broadcastToSimulator(message.toMap());
  }

  void _relayToPeers(SosMessage message, {String? excludeEndpoint}) {
    if (!_isSupported) {
      print("MeshService: Simulating Peer Relay for ${message.messageId}");
      return;
    }
    final payloadBytes = utf8.encode(jsonEncode(message.toMap()));
    for (String endpointId in connectedEndpoints) {
      if (endpointId != excludeEndpoint) {
        Nearby().sendBytesPayload(endpointId, payloadBytes);
      }
    }
  }

  /// Sends all locally stored messages to a specific peer.
  Future<void> syncWithPeer(String endpointId) async {
    print("Syncing messages with peer $endpointId...");
    final messages = await dbHelper.getMessages();
    for (final msg in messages) {
      final payloadBytes = utf8.encode(jsonEncode(msg.toMap()));
      await Nearby().sendBytesPayload(endpointId, payloadBytes);
    }
  }

  /// Triggers a sync with all connected peers.
  Future<void> broadcastSync() async {
    print("Broadcasting sync to all connected peers...");
    final messages = await dbHelper.getMessages();
    for (final msg in messages) {
      final payloadBytes = utf8.encode(jsonEncode(msg.toMap()));
      for (final endpointId in connectedEndpoints) {
        await Nearby().sendBytesPayload(endpointId, payloadBytes);
      }
    }
  }
  Future<void> sendChatMessage(ChatMessage chatMessage) async {
    await dbHelper.insertChatMessage(chatMessage);
    _relayChatToPeers(chatMessage);
    await _broadcastToSimulator(chatMessage.toMap());
  }

  void _relayChatToPeers(ChatMessage message, {String? excludeEndpoint}) {
    if (!_isSupported) {
      print("MeshService: Simulating Chat Relay for ${message.messageId}");
      return;
    }
    final payloadBytes = utf8.encode(jsonEncode(message.toMap()));
    for (String endpointId in connectedEndpoints) {
      if (endpointId != excludeEndpoint) {
        Nearby().sendBytesPayload(endpointId, payloadBytes);
      }
    }
  }

  // HTTP Mesh Simulator Sync Fallback Implementation

  // ============================================================
  // UPDATE THIS for cloud/Render deployment
  // Set `_cloudSimulatorUrl` to your public Render URL (e.g., "https://resqnet-mesh.onrender.com")
  // If empty, it will fall back to local Wi-Fi testing using `_simulatorHost`.
  // ============================================================
  static const String _cloudSimulatorUrl = ""; 
  static const String _simulatorHost = "192.168.1.53";
  static const int _simulatorPort = 5000;

  String get _simulatorBaseUrl {
    if (_cloudSimulatorUrl.isNotEmpty) {
      return _cloudSimulatorUrl.endsWith("/") 
          ? _cloudSimulatorUrl.substring(0, _cloudSimulatorUrl.length - 1)
          : _cloudSimulatorUrl;
    }
    if (kIsWeb) {
      return "http://localhost:$_simulatorPort";
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Use LAN IP for physical devices; for emulator use 10.0.2.2
      return "http://$_simulatorHost:$_simulatorPort";
    }
    return "http://localhost:$_simulatorPort";
  }

  void startSimulatorSync() {
    if (_simulatorTimer != null) return;
    _registerNodeWithSimulator();
    _simulatorTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _syncWithSimulator();
    });
  }

  void stopSimulatorSync() {
    _simulatorTimer?.cancel();
    _simulatorTimer = null;
  }

  Future<void> _registerNodeWithSimulator() async {
    try {
      final response = await http.post(
        Uri.parse("$_simulatorBaseUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"node_id": nodeId}),
      );
      if (response.statusCode == 200) {
        print("MeshService: Registered with simulator as $nodeId");
      }
    } catch (e) {
      print("MeshService: Failed to register with simulator: $e");
    }
  }

  Future<void> _syncWithSimulator() async {
    try {
      final response = await http.get(
        Uri.parse("$_simulatorBaseUrl/sync?node_id=$nodeId"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> msgs = data['messages'] ?? [];
        
        for (var item in msgs) {
          final Map<String, dynamic> msgMap = Map<String, dynamic>.from(item);
          
          if (msgMap.containsKey('sosId')) {
            // Chat Message
            final chatMsg = ChatMessage.fromMap(msgMap, nodeId);
            final chatMsgs = await dbHelper.getChatMessages(chatMsg.sosId, nodeId);
            bool chatExists = chatMsgs.any((c) => c.messageId == chatMsg.messageId);
            if (!chatExists) {
              await dbHelper.insertChatMessage(chatMsg);
              if (onChatReceived != null) onChatReceived!(chatMsg);
            }
          } else if (msgMap.containsKey('messageId') || msgMap.containsKey('message_id')) {
            // SOS Message
            final normalizedMap = _normalizeSosMessageMap(msgMap);
            final msg = SosMessage.fromMap(normalizedMap);
            
            bool exists = await dbHelper.messageExists(msg.messageId);
            if (!exists) {
              await dbHelper.insertMessage(msg);
              if (onMessageReceived != null) onMessageReceived!(msg);
            } else {
              final existingMsgs = await dbHelper.getMessages();
              final localMsg = existingMsgs.firstWhere((m) => m.messageId == msg.messageId);
              
              if (localMsg.status != msg.status || 
                  localMsg.rescuerLatitude != msg.rescuerLatitude ||
                  localMsg.rescuerLongitude != msg.rescuerLongitude) {
                await dbHelper.insertMessage(msg);
                if (onMessageReceived != null) onMessageReceived!(msg);
              }
            }
          }
        }
      }
    } catch (e) {
      // Failed to sync (simulator might be offline, ignore)
    }
  }

  Future<void> _broadcastToSimulator(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (payload.containsKey('messageId')) {
        payload['message_id'] = payload['messageId'];
      }
      
      final response = await http.post(
        Uri.parse("$_simulatorBaseUrl/broadcast"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        print("MeshService: Simulator broadcast returned ${response.statusCode}");
      }
    } catch (e) {
      print("MeshService: Failed to broadcast to simulator: $e");
    }
  }

  Map<String, dynamic> _normalizeSosMessageMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (key == 'message_id') {
        result['messageId'] = value;
      } else if (key == 'sender_id') {
        result['senderId'] = value;
      } else if (key == 'hop_count') {
        result['hopCount'] = value;
      } else if (key == 'rescuer_latitude') {
        result['rescuerLatitude'] = value;
      } else if (key == 'rescuer_longitude') {
        result['rescuerLongitude'] = value;
      } else {
        result[key] = value;
      }
    });
    if (!result.containsKey('messageId') && map.containsKey('messageId')) {
      result['messageId'] = map['messageId'];
    }
    return result;
  }
}
