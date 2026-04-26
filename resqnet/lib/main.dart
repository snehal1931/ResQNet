import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'models/message.dart';
import 'models/chat_message.dart';
import 'services/database_helper.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'services/mesh_service.dart';
import 'services/ai_scorer.dart';
import 'services/map_cache_service.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'dart:io'
    if (dart.library.html) 'package:resqnet/services/web_stubs.dart'
    as io;
import 'admin_mode_screen.dart';


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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ResQNetApp());
}

class ResQNetApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQNet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        primaryColor: const Color(0xFFEF5350),
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  String _selectedRole = 'Victim';

  void _handleLogin() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter your name")));
      return;
    }

    String prefix = 'V';
    if (_selectedRole == 'Rescuer') prefix = 'R';
    if (_selectedRole == 'Admin') prefix = 'A';

    final String nodeId = (_selectedRole == 'Rescuer' || _selectedRole == 'Admin') && _idController.text.isNotEmpty
        ? _idController.text
        : "$prefix-${_nameController.text}";

    Widget nextScreen;
    if (_selectedRole == 'Admin') {
      nextScreen = AdminModeScreen(nodeId: nodeId);
    } else if (_selectedRole == 'Rescuer') {
      nextScreen = RescuerModeScreen(nodeId: nodeId);
    } else {
      nextScreen = VictimModeScreen(userName: _nameController.text, nodeId: nodeId);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => nextScreen),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0E)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF5350).withOpacity(0.3),
                        blurRadius: 30,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.security,
                          size: 70,
                          color: Color(0xFFEF5350),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'RESQNET',
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'OFFLINE EMERGENCY NETWORK',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Glassmorphism Card for Inputs
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        _nameController,
                        "Your Name",
                        Icons.person_outline,
                      ),
                const SizedBox(height: 16),
                if (_selectedRole == 'Rescuer' || _selectedRole == 'Admin')
                  _buildTextField(
                    _idController,
                    _selectedRole == 'Admin' ? "Admin ID" : "Rescuer ID",
                    Icons.badge_outlined,
                  ),
                const SizedBox(height: 24),
                // Role Selection
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['Victim', 'Rescuer', 'Admin'].map((role) {
                      final isSelected = _selectedRole == role;
                      Color roleColor = Colors.white;
                      if (role == 'Victim') roleColor = const Color(0xFFEF5350);
                      if (role == 'Rescuer') roleColor = const Color(0xFF42A5F5);
                      if (role == 'Admin') roleColor = const Color(0xFFAB47BC);

                      return GestureDetector(
                        onTap: () => setState(() => _selectedRole = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? roleColor.withOpacity(0.2) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? roleColor : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              color: isSelected ? roleColor : Colors.white54,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRole == 'Admin'
                        ? const Color(0xFFAB47BC)
                        : (_selectedRole == 'Rescuer'
                            ? const Color(0xFF42A5F5)
                            : const Color(0xFFEF5350)),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                  ),
                  child: Text(
                    _selectedRole == 'Admin'
                        ? 'ENTER ADMIN CONSOLE'
                        : (_selectedRole == 'Rescuer'
                            ? 'LOGIN AS RESCUER'
                            : 'ENTER EMERGENCY PORTAL'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
),
);
}

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: _selectedRole == 'Admin'
                ? const Color(0xFFAB47BC)
                : (_selectedRole == 'Rescuer'
                    ? const Color(0xFF42A5F5)
                    : const Color(0xFFEF5350)),
          ),
        ),
      ),
    );
  }
}

class VictimModeScreen extends StatefulWidget {
  final String userName;
  final String nodeId;
  VictimModeScreen({required this.userName, required this.nodeId});

  @override
  _VictimModeScreenState createState() => _VictimModeScreenState();
}

class _VictimModeScreenState extends State<VictimModeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  int _headcount = 1;

  late String _nodeId;
  late MeshService _meshService;
  late AIScorer _aiScorer;
  bool _isSending = false;
  bool _hasSent = false;
  String? _sosId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _quickActions = [
    'Medical',
    'Trapped',
    'Fire',
    'Bleeding',
    'Flooded',
  ];

  @override
  void initState() {
    super.initState();
    _nodeId = widget.nodeId;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initMesh();
    _aiScorer = AIScorer();
    _aiScorer.loadModel();
    _getLocation().then((pos) {
      if (pos != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _initMesh() async {
    _meshService = MeshService(_nodeId);
    _meshService.onMessageReceived = (msg) {
      if (mounted) setState(() {});
    };
    _meshService.onChatReceived = (chat) {
      if (mounted) setState(() {});
    };
    await _meshService.requestPermissions();
    await _meshService.startAdvertising();
    await _meshService.startDiscovery();

    // Check for existing SOS from this user
    final messages = await DatabaseHelper().getMessages();
    try {
      final mySos = messages.firstWhere(
        (m) => m.senderId == _nodeId && m.status != 'RESOLVED',
      );
      if (mounted) {
        setState(() {
          _sosId = mySos.messageId;
          _hasSent = true;
          _contentController.text = mySos.content;
          _headcount = mySos.headcount;
        });
      }
    } catch (e) {
      // No active session
    }
  }

  void _addQuickAction(String action) {
    setState(() {
      if (_contentController.text.isNotEmpty) {
        _contentController.text += ', $action';
      } else {
        _contentController.text = action;
      }
    });
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _sendSos() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      Position? pos;
      try {
        pos = await _getLocation();
      } catch (e) {
        print("Location fetch failed: $e");
      }

      final severity = _aiScorer.scoreSignal(_contentController.text);

      final message = SosMessage(
        messageId: const Uuid().v4(),
        senderId: _nodeId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        content: _contentController.text.isEmpty
            ? "Distress signal from ${widget.userName}"
            : _contentController.text,
        headcount: _headcount,
        severity: severity,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
      );

      await DatabaseHelper().insertMessage(message);
      await _meshService.broadcastMessage(message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Beacon Broadcasted ($severity)'),
            backgroundColor: severity == 'CRITICAL'
                ? Colors.red
                : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send SOS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _contentController.clear();
          _headcount = 1;
        });
      }
    }

    _listenForStatus();
  }

  void _listenForStatus() {
    Timer.periodic(const Duration(seconds: 3), (timer) async {
      final msgs = await DatabaseHelper().getMessages();
      final myMsg = msgs.firstWhere(
        (m) => m.senderId == _nodeId,
        orElse: () => SosMessage(
          messageId: '',
          senderId: '',
          timestamp: 0,
          content: '',
          headcount: 0,
          severity: '',
        ),
      );
      if (myMsg.messageId.isNotEmpty && mounted) {
        setState(() {});
      }
      if (!mounted) timer.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Beacon'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
          _buildStatusIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Logged in as: ${widget.userName}",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "DESCRIBE SITUATION",
                    style: GoogleFonts.inter(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      hintText: 'Describe your situation...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickActions
                        .map(
                          (action) => ActionChip(
                            label: Text(
                              action,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: const Color(
                              0xFFEF5350,
                            ).withOpacity(0.15),
                            labelStyle: const TextStyle(
                              color: Color(0xFFEF5350),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: const Color(0xFFEF5350).withOpacity(0.3),
                              ),
                            ),
                            onPressed: () => _addQuickAction(action),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                  _buildSmartHeadcounter(),
                  const SizedBox(height: 60),
                  Center(
                    child: _isSending
                        ? const CircularProgressIndicator(color: Colors.red)
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              // Radar Rings
                              ...List.generate(3, (index) {
                                return AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    double progress =
                                        (_pulseController.value + (index / 3)) %
                                        1.0;
                                    return Container(
                                      height: 200 + (progress * 150),
                                      width: 200 + (progress * 150),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(
                                            0xFFEF5350,
                                          ).withOpacity(1.0 - progress),
                                          width: 2,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                              // Main Pulsing Button
                              GestureDetector(
                                onTap: _sendSos,
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _pulseAnimation.value,
                                      child: Container(
                                        height: 200,
                                        width: 200,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFB71C1C),
                                              Color(0xFFEF5350),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFEF5350,
                                              ).withOpacity(0.4),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            ),
                                          ],
                                        ),
                                        child: const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.wifi_tethering,
                                              size: 60,
                                              color: Colors.white,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              "BROADCAST",
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              "SOS",
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w300,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return FutureBuilder<List<SosMessage>>(
      future: DatabaseHelper().getMessages(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final myMsgs = snapshot.data!
            .where((m) => m.senderId == _nodeId)
            .toList();
        if (myMsgs.isEmpty) return const SizedBox();

        final latest = myMsgs.first;
        Color statusColor = Colors.white24;
        IconData statusIcon = Icons.hourglass_empty;
        String statusText = "WAITING FOR RESPONDERS";

        if (latest.status == 'RESCUING') {
          statusColor = const Color(0xFFFFA726);
          statusIcon = Icons.directions_run;
          statusText = "HELP IS ON THE WAY!";
        } else if (latest.status == 'RESOLVED') {
          statusColor = const Color(0xFF66BB6A);
          statusIcon = Icons.check_circle;
          statusText = "SITUATION RESOLVED";
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            border: Border(
              bottom: BorderSide(color: statusColor.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      "Active in mesh network",
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (latest.status == 'RESCUING')
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (c) => TrackingMapDialog(
                            rescuerLat: latest.rescuerLatitude,
                            rescuerLng: latest.rescuerLongitude,
                            myLat: latest.latitude,
                            myLng: latest.longitude,
                          ),
                        );
                      },
                      icon: const Icon(Icons.location_on, size: 14),
                      label: const Text(
                        "TRACK",
                        style: TextStyle(fontSize: 10),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.chat_bubble_outline,
                        color: statusColor,
                        size: 20,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => MeshChatScreen(
                            meshService: _meshService,
                            sosId: latest.messageId,
                            otherPartyId:
                                "RESCUER", // In reality, we'd get the actual rescuer nodeId
                            title: "Rescuer Chat",
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSmartHeadcounter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          const Text(
            "HOW MANY PEOPLE ARE IN TROUBLE?",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _counterButton(Icons.remove, () {
                if (_headcount > 1) setState(() => _headcount--);
              }),
              const SizedBox(width: 40),
              Column(
                children: [
                  Text(
                    "$_headcount",
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _headcount == 1 ? "Person" : "People",
                    style: const TextStyle(fontSize: 14, color: Colors.white30),
                  ),
                ],
              ),
              const SizedBox(width: 40),
              _counterButton(Icons.add, () {
                if (_headcount < 99) setState(() => _headcount++);
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class RescuerModeScreen extends StatefulWidget {
  final String nodeId;
  RescuerModeScreen({required this.nodeId});

  @override
  _RescuerModeScreenState createState() => _RescuerModeScreenState();
}

class _RescuerModeScreenState extends State<RescuerModeScreen> {
  late String _nodeId;
  late MeshService _meshService;
  List<SosMessage> _messages = [];
  Position? _currentPosition;
  Timer? _locationTimer;
  Timer? _syncTimer;
  bool _isMapView = false;

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
    _startLocationTracking();
    _startSyncTimer(); // FIX: Periodic sync to pull messages from mesh
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // FIX: Periodic sync timer to ensure messages are pulled from mesh network
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted) {
        await _meshService.broadcastSync();
        _loadLocalMessages();
      }
    });
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
          _loadLocalMessages();

          // If we are actively rescuing someone, broadcast our location to the mesh
          for (var msg in _messages) {
            if (msg.status == 'RESCUING') {
              await _meshService.broadcastRescuerLocation(
                msg.messageId,
                pos.latitude,
                pos.longitude,
              );
            }
          }
        }
      } catch (e) {
        print("Error getting rescuer location: $e");
      }
    });
  }

  Future<void> _initMesh() async {
    _meshService = MeshService(_nodeId);
    _meshService.onMessageReceived = (msg) {
      if (mounted) _loadLocalMessages();
    };
    await _meshService.requestPermissions();
    await _meshService.startAdvertising();
    await _meshService.startDiscovery();

    // FIX: Force initial sync when rescuer logs in
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        await _meshService.broadcastSync();
        _loadLocalMessages();
      }
    });
  }

  void _loadLocalMessages() async {
    final msgs = await DatabaseHelper().getMessages();

    msgs.sort((a, b) {
      if (a.severity == 'CRITICAL' && b.severity != 'CRITICAL') return -1;
      if (b.severity == 'CRITICAL' && a.severity != 'CRITICAL') return 1;
      if (_currentPosition != null &&
          a.latitude != null &&
          b.latitude != null) {
        double distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude!,
          a.longitude!,
        );
        double distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude!,
          b.longitude!,
        );
        return distA.compareTo(distB);
      }
      return b.timestamp.compareTo(a.timestamp);
    });

    if (mounted) setState(() => _messages = msgs);
  }

  void _runDemo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulating Emergency Mesh Signals...'),
        backgroundColor: Colors.purple,
      ),
    );

    double baseLat = _currentPosition?.latitude ?? 18.5204;
    double baseLng = _currentPosition?.longitude ?? 73.8567;

    List<SosMessage> demoMsgs = [
      SosMessage(
        messageId: 'demo-1',
        senderId: 'victim-alice',
        timestamp: DateTime.now().millisecondsSinceEpoch - 100000,
        content:
            "FLASH FLOOD! Trapped on roof with 2 children. Water rising fast.",
        headcount: 3,
        severity: 'CRITICAL',
        latitude: baseLat + 0.002,
        longitude: baseLng + 0.003,
      ),
      SosMessage(
        messageId: 'demo-2',
        senderId: 'victim-bob',
        timestamp: DateTime.now().millisecondsSinceEpoch - 50000,
        content:
            "Chest pain and difficulty breathing. Near the old clock tower.",
        headcount: 1,
        severity: 'HIGH',
        latitude: baseLat - 0.001,
        longitude: baseLng + 0.001,
      ),
      SosMessage(
        messageId: 'demo-3',
        senderId: 'victim-charlie',
        timestamp: DateTime.now().millisecondsSinceEpoch - 20000,
        content: "Blocked road, need help with clearing debris. No injuries.",
        headcount: 5,
        severity: 'LOW',
        latitude: baseLat + 0.005,
        longitude: baseLng - 0.002,
      ),
    ];

    for (var m in demoMsgs) {
      await DatabaseHelper().insertMessage(m);
    }

    _loadLocalMessages();
  }

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

  Future<void> _openMap(double lat, double lng) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Launching Map...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
    final appleUrl = Uri.parse('http://maps.apple.com/?q=$lat,$lng');

    try {
      if (await canLaunchUrl(geoUrl)) {
        await launchUrl(geoUrl);
      } else if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(appleUrl)) {
        await launchUrl(appleUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No Map app found. Using browser...')),
          );
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening map: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rescuer Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Color(0xFF42A5F5)),
            tooltip: "Manual Sync",
            onPressed: () {
              _meshService.broadcastSync();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing with nearby peers...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.purpleAccent,
            ),
            tooltip: "Demo Mode",
            onPressed: _runDemo,
          ),
          IconButton(
            icon: Icon(
              _isMapView ? Icons.list : Icons.map_outlined,
              color: const Color(0xFF42A5F5),
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
                    meshService: _meshService,
                  )
                : (_messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.radar,
                                size: 80,
                                color: Colors.white10,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "SCANNING FOR SIGNALS",
                                style: TextStyle(
                                  color: Colors.white24,
                                  letterSpacing: 2,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final color = _getSeverityColor(msg.severity);
                            final bool isCritical = msg.severity == 'CRITICAL';

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
                                boxShadow: isCritical
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.35),
                                          blurRadius: 25,
                                          spreadRadius: -2,
                                        ),
                                      ]
                                    : [],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildPriorityBadge(
                                              msg.severity,
                                              color,
                                              isCritical,
                                            ),
                                            const SizedBox(width: 8),
                                            _buildStatusBadge(msg.status),
                                            const Spacer(),
                                            const Icon(
                                              Icons.access_time_filled,
                                              size: 14,
                                              color: Colors.white24,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateTime.fromMillisecondsSinceEpoch(
                                                msg.timestamp,
                                              ).toString().substring(11, 16),
                                              style: const TextStyle(
                                                color: Colors.white24,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          msg.content,
                                          style: GoogleFonts.inter(
                                            fontSize: 18,
                                            height: 1.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            _buildProminentHeadcount(
                                              msg.headcount,
                                            ),
                                            const SizedBox(width: 12),
                                            if (_currentPosition != null &&
                                                msg.latitude != null)
                                              _buildDistanceBadge(
                                                msg.latitude!,
                                                msg.longitude!,
                                              ),
                                            const Spacer(),
                                            if (msg.status == 'PENDING')
                                              _buildActionButton(
                                                "ACCEPT",
                                                const Color(0xFFFFA726),
                                                () => _meshService
                                                    .broadcastStatusUpdate(
                                                      msg.messageId,
                                                      'RESCUING',
                                                    ),
                                              )
                                            else if (msg.status == 'RESCUING')
                                              _buildActionButton(
                                                "RESOLVE",
                                                const Color(0xFF66BB6A),
                                                () => _meshService
                                                    .broadcastStatusUpdate(
                                                      msg.messageId,
                                                      'RESOLVED',
                                                    ),
                                              ),

                                            if (msg.status == 'RESCUING') ...[
                                              const SizedBox(width: 8),
                                              _buildCircleIcon(
                                                Icons.chat_bubble_rounded,
                                                const Color(0xFF42A5F5),
                                                () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (c) =>
                                                        MeshChatScreen(
                                                          meshService:
                                                              _meshService,
                                                          sosId: msg.messageId,
                                                          otherPartyId:
                                                              msg.senderId,
                                                          title: "Victim Chat",
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (msg.latitude != null) ...[
                                              const SizedBox(width: 8),
                                              _buildCircleIcon(
                                                Icons.map_rounded,
                                                const Color(0xFF42A5F5),
                                                () => _openMap(
                                                  msg.latitude!,
                                                  msg.longitude!,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
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
            "OPERATION PULSE",
            style: TextStyle(
              color: Colors.white38,
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
              _buildStatChip(
                "IN PROGRESS",
                "$rescuing",
                const Color(0xFFFFA726),
              ),
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
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.white24;
    String text = status;
    if (status == 'RESCUING') color = const Color(0xFFFFA726);
    if (status == 'RESOLVED') color = const Color(0xFF66BB6A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDistanceBadge(double lat, double lng) {
    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );

    String distanceStr = distance < 1000
        ? "${distance.toStringAsFixed(0)}m"
        : "${(distance / 1000).toStringAsFixed(1)}km";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF42A5F5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me, size: 10, color: Color(0xFF42A5F5)),
          const SizedBox(width: 4),
          Text(
            distanceStr,
            style: const TextStyle(
              color: Color(0xFF42A5F5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String severity, Color color, bool isCritical) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          if (isCritical)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: Icon(Icons.warning_amber_rounded, color: color, size: 14),
            ),
          Text(
            severity,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProminentHeadcount(int headcount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          Text(
            "$headcount",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            headcount == 1 ? "PERSON" : "PEOPLE",
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        elevation: 4,
        shadowColor: color.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class TrackingMapDialog extends StatelessWidget {
  final double? rescuerLat, rescuerLng, myLat, myLng;
  TrackingMapDialog({this.rescuerLat, this.rescuerLng, this.myLat, this.myLng});

  @override
  Widget build(BuildContext context) {
    final center = myLat != null
        ? LatLng(myLat!, myLng!)
        : LatLng(18.5204, 73.8567);

    return Dialog(
      backgroundColor: const Color(0xFF0A0A0E),
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: const Row(
              children: [
                Icon(Icons.radar, color: Colors.orange, size: 20),
                SizedBox(width: 12),
                Text(
                  "RESCUER TRACKING",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Spacer(),
                CloseButton(color: Colors.white54),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
              child: FlutterMap(
                options: MapOptions(initialCenter: center, initialZoom: 16),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  MarkerLayer(
                    markers: [
                      if (myLat != null)
                        Marker(
                          point: LatLng(myLat!, myLng!),
                          width: 80,
                          height: 80,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ),
                      if (rescuerLat != null)
                        Marker(
                          point: LatLng(rescuerLat!, rescuerLng!),
                          width: 80,
                          height: 80,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.orange, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.directions_run,
                                  color: Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "RESCUER",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (rescuerLat == null)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Waiting for rescuer location sync...",
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class MeshChatScreen extends StatefulWidget {
  final MeshService meshService;
  final String sosId;
  final String otherPartyId;
  final String title;

  MeshChatScreen({
    required this.meshService,
    required this.sosId,
    required this.otherPartyId,
    required this.title,
  });

  @override
  _MeshChatScreenState createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends State<MeshChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _currentlyPlayingId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    widget.meshService.onChatReceived = (msg) {
      if (msg.sosId == widget.sosId) _loadMessages();
    };
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    final msgs = await DatabaseHelper().getChatMessages(
      widget.sosId,
      widget.meshService.nodeId,
    );
    if (mounted) setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    if (_msgController.text.isEmpty) return;
    final chat = ChatMessage(
      messageId: const Uuid().v4(),
      senderId: widget.meshService.nodeId,
      receiverId: widget.otherPartyId,
      sosId: widget.sosId,
      content: _msgController.text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await widget.meshService.sendChatMessage(chat);
    _msgController.clear();
    _loadMessages();
  }

  void _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final directory = await getApplicationDocumentsDirectory();
      final tempPath = "${directory.path}/temp_record_${DateTime.now().millisecondsSinceEpoch}.m4a";
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: tempPath);
      setState(() => _isRecording = true);
    }
  }

  void _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path != null) {
      final chat = ChatMessage(
        messageId: const Uuid().v4(),
        senderId: widget.meshService.nodeId,
        receiverId: widget.otherPartyId,
        sosId: widget.sosId,
        content: "",
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await widget.meshService.sendChatMessageWithAudio(chat, io.File(path));
      _loadMessages();
    }
  }

  void _playAudio(String messageId, String path) async {
    if (_currentlyPlayingId == messageId) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _currentlyPlayingId = messageId);
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => _currentlyPlayingId = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                return Align(
                  alignment: m.isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: m.isMe
                          ? const Color(0xFF42A5F5).withOpacity(0.9)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20).copyWith(
                        bottomRight: m.isMe ? Radius.zero : null,
                        bottomLeft: !m.isMe ? Radius.zero : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: m.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (m.audioPath != null && m.audioPath!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _playAudio(m.messageId, m.audioPath!),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _currentlyPlayingId == m.messageId ? const Color(0xFF42A5F5) : Colors.transparent),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _currentlyPlayingId == m.messageId ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text("Voice Message", style: TextStyle(fontWeight: FontWeight.bold)),
                                  if (_currentlyPlayingId == m.messageId) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        if (m.imagePath != null && m.imagePath!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.network(
                                    m.imagePath!,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  )
                                : Image.file(
                                    io.File(m.imagePath!) as dynamic,
                                    width: 200,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 200,
                                        color: Colors.grey,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.white,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        if (m.content.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Text(
                              m.content,
                              style: const TextStyle(height: 1.3),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  _buildChatActionButton(Icons.add_a_photo_rounded, _pickImage),
                  const SizedBox(width: 8),
                  GestureDetector(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : Colors.white.withOpacity(0.05),
                        shape: BoxShape.circle,
                        boxShadow: _isRecording ? [const BoxShadow(color: Colors.red, blurRadius: 10, spreadRadius: 2)] : [],
                      ),
                      child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 20),
                    ),
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressEnd: (_) => _stopRecording(),
                    onTap: () {
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hold to record voice message'), duration: Duration(seconds: 1)));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildChatActionButton(
                    Icons.send_rounded,
                    _sendMessage,
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatActionButton(
    IconData icon,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF42A5F5)
              : Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final chat = ChatMessage(
        messageId: const Uuid().v4(),
        senderId: widget.meshService.nodeId,
        receiverId: widget.otherPartyId,
        sosId: widget.sosId,
        content: _msgController.text, // Include text if typed
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await widget.meshService.sendChatMessageWithImage(
        chat,
        io.File(pickedFile.path),
      );
      _msgController.clear();
      _loadMessages();
    }
  }
}

class RescuerMapWidget extends StatefulWidget {
  final List<SosMessage> messages;
  final Position? currentPosition;
  final MeshService? meshService;

  RescuerMapWidget({required this.messages, this.currentPosition, this.meshService});

  @override
  _RescuerMapWidgetState createState() => _RescuerMapWidgetState();
}



class _RescuerMapWidgetState extends State<RescuerMapWidget> {
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = widget.currentPosition != null
        ? LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude)
        : (widget.messages.isNotEmpty && widget.messages.first.latitude != null
              ? LatLng(widget.messages.first.latitude!, widget.messages.first.longitude!)
              : LatLng(18.5204, 73.8567));

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 15),
      children: [
        FutureBuilder<CacheStore>(
          future: MapCacheService.cacheStore,
          builder: (context, snapshot) {
            return TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.resqnet.app',
              tileProvider: snapshot.hasData
                  ? CachedTileProvider(
                      store: snapshot.data!,
                      maxStale: const Duration(days: 30),
                    )
                  : NetworkTileProvider(),
              tileBuilder: (context, tileWidget, tile) {
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: 1.0,
                  child: tileWidget,
                );
              },
            );
          },
        ),
        MarkerLayer(
          markers: [
            if (widget.currentPosition != null)
              Marker(
                point: LatLng(
                  widget.currentPosition!.latitude,
                  widget.currentPosition!.longitude,
                ),
                width: 80,
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "YOU",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ...widget.messages.where((m) => m.latitude != null).map((m) {
              final color = _getSeverityColor(m.severity);
              final isCritical = m.severity == 'CRITICAL';
              return Marker(
                point: LatLng(m.latitude!, m.longitude!),
                width: 100,
                height: 100,
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (c) => _buildMarkerDialog(context, m, color),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isCritical ? 10 : 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: isCritical ? 2.5 : 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: isCritical ? 20 : 10,
                              spreadRadius: isCritical ? 5 : 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.radar_rounded,
                          color: color,
                          size: isCritical ? 28 : 22,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isCritical)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "CRITICAL",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            ...widget.messages
                .where(
                  (m) => m.rescuerLatitude != null && m.status == 'RESCUING',
                )
                .map((m) {
                  return Marker(
                    point: LatLng(m.rescuerLatitude!, m.rescuerLongitude!),
                    width: 60,
                    height: 60,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.orange, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.directions_run_outlined,
                            color: Colors.orange,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "RESCUER",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
          ],
        ),
      ],
    );
  }

  Widget _buildMarkerDialog(BuildContext context, SosMessage m, Color color) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E).withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: color.withOpacity(0.3)),
      ),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Text(
            m.severity,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.content,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMarkerInfoRow(Icons.group, "People: ${m.headcount}"),
                const SizedBox(height: 8),
                _buildMarkerInfoRow(Icons.info_outline, "Status: ${m.status}"),
                const SizedBox(height: 8),
                _buildMarkerInfoRow(
                  Icons.access_time,
                  "Time: ${DateTime.fromMillisecondsSinceEpoch(m.timestamp).toString().substring(11, 16)}",
                ),
                if (m.latitude != null) ...[
                  const SizedBox(height: 8),
                  _buildMarkerInfoRow(
                    Icons.location_on,
              "${(m.latitude ?? 0).toStringAsFixed(4)}, ${(m.longitude ?? 0).toStringAsFixed(4)}",
            ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CLOSE", style: TextStyle(color: Colors.white38)),
        ),
        if (m.status == 'RESCUING' && widget.meshService != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (c) => MeshChatScreen(
                meshService: widget.meshService!,
                sosId: m.messageId,
                otherPartyId: m.senderId,
                title: "Victim Chat",
              )));
            },
            child: const Text("CHAT", style: TextStyle(color: Color(0xFF42A5F5))),
          ),
        if (m.status == 'PENDING')
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.meshService?.broadcastStatusUpdate(
                m.messageId,
                'RESCUING',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
            ),
            child: const Text("ACCEPT"),
          )
        else if (m.status == 'RESCUING')
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.meshService?.broadcastStatusUpdate(
                m.messageId,
                'RESOLVED',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.black,
            ),
            child: const Text("RESOLVE"),
          ),
      ],
    );
  }

  Widget _buildMarkerInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

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
}
