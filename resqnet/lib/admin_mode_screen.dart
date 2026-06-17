import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'models/message.dart';
import 'services/database_helper.dart';
import 'services/mesh_service.dart';
import 'main.dart'; // To access RescuerMapWidget, LoginScreen

Color _getSeverityColor(String severity) {
  switch (severity) {
    case 'CRITICAL':
      return const Color(0xFFEF5350);
    case 'HIGH':
      return const Color(0xFFFFA726);
    case 'LOW':
      return const Color(0xFF66BB6A);
    default:
      return Colors.grey;
  }
}

class AdminModeScreen extends StatefulWidget {
  final String nodeId;
  AdminModeScreen({required this.nodeId});

  @override
  _AdminModeScreenState createState() => _AdminModeScreenState();
}

class _AdminModeScreenState extends State<AdminModeScreen> {
  late String _nodeId;
  late MeshService _meshService;
  List<SosMessage> _messages = [];
  Position? _currentPosition;
  Timer? _syncTimer;
  bool _isMapView = true;

  @override
  void initState() {
    super.initState();
    _nodeId = widget.nodeId;
    _initMesh();
    _loadLocalMessages();
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    ).then((pos) {
      if (mounted) setState(() => _currentPosition = pos);
    });
    _startSyncTimer();
  }

  @override
  void dispose() {
    _meshService.stopSimulatorSync();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        await _meshService.broadcastSync();
        _loadLocalMessages();
      }
    });
  }

  Future<void> _initMesh() async {
    _meshService = MeshService(_nodeId);
    _meshService.onMessageReceived = (msg) {
      if (mounted) _loadLocalMessages();
    };
    await _meshService.requestPermissions();
    // Admin listens to everything
    await _meshService.startAdvertising();
    await _meshService.startDiscovery();

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        await _meshService.broadcastSync();
        _loadLocalMessages();
      }
    });
  }

  void _loadLocalMessages() async {
    final msgs = await DatabaseHelper().getMessages();
    msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (mounted) setState(() => _messages = msgs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console', style: TextStyle(color: Color(0xFFAB47BC), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFFAB47BC)),
            tooltip: "Manual Sync",
            onPressed: () {
              _meshService.broadcastSync();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing with nearby peers...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _isMapView ? Icons.list : Icons.map_outlined,
              color: const Color(0xFFAB47BC),
            ),
            tooltip: _isMapView ? "List View" : "Map View",
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => LoginScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPulseDashboard(),
          Expanded(
            child: _isMapView
                ? RescuerMapWidget(
                    messages: _messages,
                    currentPosition: _currentPosition,
                    meshService: null, // Admin cannot chat from map
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final color = _getSeverityColor(msg.severity);
                      final isCritical = msg.severity == 'CRITICAL';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isCritical
                              ? color.withOpacity(0.12)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isCritical
                                ? color.withOpacity(0.6)
                                : color.withOpacity(0.2),
                            width: isCritical ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(msg.severity, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Text("[${msg.status}]", style: const TextStyle(color: Colors.white54)),
                                      const Spacer(),
                                      Text(
                                        DateTime.fromMillisecondsSinceEpoch(msg.timestamp).toString().substring(11, 16),
                                        style: const TextStyle(color: Colors.white24, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    msg.content,
                                    style: GoogleFonts.inter(fontSize: 16, color: Colors.white),
                                  ),
                                  const SizedBox(height: 16),
                                  Text("Victim Node ID: ${msg.senderId}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  Text("People: ${msg.headcount}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  if (msg.latitude != null && msg.longitude != null)
                                    Text("Victim Loc: ${msg.latitude!.toStringAsFixed(4)}, ${msg.longitude!.toStringAsFixed(4)}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                  if (msg.rescuerLatitude != null && msg.rescuerLongitude != null)
                                    Text("Rescuer Loc: ${msg.rescuerLatitude!.toStringAsFixed(4)}, ${msg.rescuerLongitude!.toStringAsFixed(4)}", style: const TextStyle(color: Colors.orange, fontSize: 12)),
                                  const SizedBox(height: 12),
                                  if (msg.latitude != null || (msg.rescuerLatitude != null))
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.location_searching, size: 16),
                                      label: const Text("Track Details on Map"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.1),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (c) => TrackingMapDialog(
                                            myLat: msg.latitude,
                                            myLng: msg.longitude,
                                            rescuerLat: msg.rescuerLatitude,
                                            rescuerLng: msg.rescuerLongitude,
                                          ),
                                        );
                                      },
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
        ],
      ),
    );
  }

  Widget _buildPulseDashboard() {
    final total = _messages.length;
    final critical = _messages.where((m) => m.severity == 'CRITICAL').length;
    final rescuing = _messages.where((m) => m.status == 'RESCUING').length;
    final resolved = _messages.where((m) => m.status == 'RESOLVED').length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "GLOBAL ADMIN DASHBOARD",
            style: TextStyle(
              color: Color(0xFFAB47BC),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatChip("TOTAL", "$total", Colors.white38),
              const SizedBox(width: 12),
              _buildStatChip("CRITICAL", "$critical", const Color(0xFFEF5350)),
              const SizedBox(width: 12),
              _buildStatChip("IN PROGRESS", "$rescuing", const Color(0xFFFFA726)),
              const SizedBox(width: 12),
              _buildStatChip("RESOLVED", "$resolved", const Color(0xFF66BB6A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
