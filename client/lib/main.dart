import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const ChatApp());
}

// ============================================================
// COLORES
// ============================================================

class AppColors {
  static const Color primary = Color(0xFF1F5D42);
  static const Color primaryDark = Color(0xFF163D2D);
  static const Color primarySoft = Color(0xFFDDF2E6);

  static const Color background = Color(0xFFF3F7F5);
  static const Color chatBackground = Color(0xFFF0F5F2);

  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF18201C);
  static const Color textSecondary = Color(0xFF6B756F);

  static const Color border = Color(0xFFDCE5E0);
}

// ============================================================
// APP
// ============================================================

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CDD Connect',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const ConnectScreen(),
    );
  }
}

// ============================================================
// MODELOS
// ============================================================

class Request {
  final String type;
  final String user;
  final String? text;
  final int? timestamp;

  Request({required this.type, required this.user, this.text, this.timestamp});

  Map<String, dynamic> toJson() => {
    'type': type,
    'user': user,
    if (text != null) 'text': text,
    if (timestamp != null) 'timestamp': timestamp,
  };
}

class Event {
  final String type;
  final int? id;
  final String user;
  final String text;
  final DateTime? time;
  final int? timestamp;

  final double cpuPercent;
  final int memoryBytes;
  final int connectedUsers;

  Event({
    required this.type,
    this.id,
    required this.user,
    required this.text,
    this.time,
    this.timestamp,
    this.cpuPercent = 0.0,
    this.memoryBytes = 0,
    this.connectedUsers = 0,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      type: json['type'] ?? '',
      id: (json['id'] as num?)?.toInt(),
      user: json['user'] ?? 'Sistema',
      text: json['text'] ?? '',
      time: json['time'] != null
          ? DateTime.parse(json['time']).toLocal()
          : null,
      timestamp: (json['timestamp'] as num?)?.toInt(),
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memoryBytes: (json['memory_bytes'] as num?)?.toInt() ?? 0,
      connectedUsers: (json['connected_users'] as num?)?.toInt() ?? 0,
    );
  }
}

// ============================================================
// LOGO CDD
// ============================================================

class CddLogo extends StatelessWidget {
  final double size;

  const CddLogo({super.key, this.size = 76});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'CDD',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ============================================================
// CONEXIÓN
// ============================================================

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ipController = TextEditingController(text: '127.0.0.1');

  final _portController = TextEditingController(text: '9000');

  final _userController = TextEditingController();

  bool _isLoading = false;

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9000;
    final username = _userController.text.trim();

    if (username.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(seconds: 5),
      );

      final joinReq = Request(type: 'join', user: username);

      socket.writeln(jsonEncode(joinReq.toJson()));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            socket: socket,
            username: username,
            serverIp: ip,
            serverPort: port,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _userController.dispose();

    super.dispose();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: const BoxDecoration(color: AppColors.primaryDark),
      child: Row(
        children: [
          Image.asset(
            'assets/logo_unal_blanco.png',
            height: 48,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Universidad Nacional de Colombia',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Sistemas Embebidos Linux',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: 450,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CddLogo(size: 82),

          const SizedBox(height: 18),

          const Text(
            'CDD Connect',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Chat local corporativo',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),

          const SizedBox(height: 4),

          const Text(
            'Sistemas Embebidos Linux',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 30),

          _field(
            controller: _ipController,
            label: 'Dirección IP del servidor',
            icon: Icons.dns_outlined,
          ),

          const SizedBox(height: 14),

          _field(
            controller: _portController,
            label: 'Puerto',
            icon: Icons.settings_ethernet,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 14),

          _field(
            controller: _userController,
            label: 'Tu nombre',
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _connect,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Entrar al chat',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 19),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 26),

          const Divider(),

          const SizedBox(height: 15),

          const Text(
            'Equipo CDD',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Camilo  •  Daniela  •  David',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Proyecto académico · Universidad Nacional de Colombia',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),

          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF7FAF8), Color(0xFFEDF4F0)],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 42,
                ),
                child: Center(child: _buildLoginCard()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHAT
// ============================================================

class ChatScreen extends StatefulWidget {
  final Socket socket;
  final String username;
  final String serverIp;
  final int serverPort;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.username,
    required this.serverIp,
    required this.serverPort,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Event> _messages = [];

  final TextEditingController _msgController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  Timer? _pingTimer;

  double _latencyMs = 0.0;
  double _jitterMs = 0.0;
  double? _previousLatencyMs;

  double _cpuPercent = 0.0;
  int _memoryBytes = 0;
  int _connectedUsers = 0;

  int _receivedMessages = 0;

  bool _connected = true;
  bool _showMetrics = false;

  @override
  void initState() {
    super.initState();

    _listenSocket();
    _startMetrics();
  }

  // ==========================================================
  // LÓGICA ORIGINAL - SIN CAMBIOS
  // ==========================================================

  void _startMetrics() {
    _sendPing();

    _pingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendPing());
  }

  void _sendPing() {
    if (!_connected) return;

    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final req = Request(
      type: 'ping',
      user: widget.username,
      timestamp: timestamp,
    );

    try {
      widget.socket.writeln(jsonEncode(req.toJson()));
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _listenSocket() {
    widget.socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty) {
              return;
            }

            try {
              final Map<String, dynamic> jsonMap = jsonDecode(line);

              final event = Event.fromJson(jsonMap);

              if (event.type == 'pong' && event.timestamp != null) {
                final now = DateTime.now().microsecondsSinceEpoch;

                final latency = (now - event.timestamp!) / 1000.0;

                double jitter = 0.0;

                if (_previousLatencyMs != null) {
                  jitter = (latency - _previousLatencyMs!).abs();
                }

                if (!mounted) return;

                setState(() {
                  _latencyMs = latency;
                  _jitterMs = jitter;
                  _previousLatencyMs = latency;

                  _cpuPercent = event.cpuPercent;

                  _memoryBytes = event.memoryBytes;

                  _connectedUsers = event.connectedUsers;
                });

                return;
              }

              if (event.type == 'message') {
                if (!mounted) return;

                setState(() {
                  _messages.add(event);
                  _receivedMessages++;
                });

                _scrollToBottom();
              } else if (event.type == 'error') {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚠️ Error: ${event.text}')),
                );
              }
            } catch (_) {}
          },
          onDone: _handleDisconnect,
          onError: (_) => _handleDisconnect(),
        );
  }

  void _sendMessage() {
    final text = _msgController.text.trim();

    if (text.isEmpty) return;

    final req = Request(type: 'message', user: widget.username, text: text);

    widget.socket.writeln(jsonEncode(req.toJson()));

    _msgController.clear();
  }

  void _handleDisconnect() {
    if (!_connected) return;

    _connected = false;
    _pingTimer?.cancel();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conexión finalizada por el servidor')),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ConnectScreen()),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';

    final hh = dt.hour.toString().padLeft(2, '0');

    final mm = dt.minute.toString().padLeft(2, '0');

    return '$hh:$mm';
  }

  String _formatMemory(int bytes) {
    if (bytes <= 0) {
      return 'Midiendo...';
    }

    final mb = bytes / (1024 * 1024);

    return '${mb.toStringAsFixed(1)} MB';
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _avatar(String name, {double radius = 17}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFDCEFE4),
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  // ==========================================================
  // FONDO MODERNO
  // ==========================================================

  Widget _buildChatBackground() {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7FAF8), Color(0xFFEDF4F0)],
              ),
            ),
          ),
        ),

        Positioned(
          top: -80,
          right: -70,
          child: Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x0D1F5D42),
            ),
          ),
        ),

        Positioned(
          bottom: -100,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x0A1F5D42),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildChatHeader() {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const CddLogo(size: 46),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CDD Connect',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Sistemas Embebidos Linux · $_connectedUsers conectados',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _connected
                  ? const Color(0xFFE3F4E9)
                  : const Color(0xFFFCE6E6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? Colors.green : Colors.red,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _connected ? 'En línea' : 'Sin conexión',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Métricas',
            onPressed: () {
              setState(() {
                _showMetrics = !_showMetrics;
              });
            },
            icon: Icon(
              Icons.analytics_outlined,
              color: _showMetrics ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MÉTRICAS
  // ==========================================================

  Widget _metricItem(IconData icon, String title, String value) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 19,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Métricas del sistema',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),

              IconButton(
                onPressed: () {
                  setState(() {
                    _showMetrics = false;
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricItem(
                Icons.speed,
                'Latencia',
                _previousLatencyMs == null
                    ? 'Midiendo...'
                    : '${_latencyMs.toStringAsFixed(2)} ms',
              ),
              _metricItem(
                Icons.timeline,
                'Jitter',
                _previousLatencyMs == null
                    ? 'Midiendo...'
                    : '${_jitterMs.toStringAsFixed(2)} ms',
              ),
              _metricItem(
                Icons.memory,
                'CPU',
                '${_cpuPercent.toStringAsFixed(2)} %',
              ),
              _metricItem(
                Icons.storage_outlined,
                'Memoria',
                _formatMemory(_memoryBytes),
              ),
              _metricItem(Icons.people_outline, 'Usuarios', '$_connectedUsers'),
              _metricItem(
                Icons.message_outlined,
                'Mensajes',
                '$_receivedMessages',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // MENSAJES
  // ==========================================================

  Widget _buildSystemMessage(Event msg) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 9),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          msg.text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, Event msg) {
    final isMe = msg.user == widget.username;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[_avatar(msg.user), const SizedBox(width: 8)],

          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.60,
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE4F4EA), Color(0xFFD4ECDD)],
                      )
                    : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 5),
                  bottomRight: Radius.circular(isMe ? 5 : 18),
                ),
                border: Border.all(
                  color: isMe ? const Color(0xFFC2E0CD) : AppColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        msg.user,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                  Text(
                    msg.text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(msg.time),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),

                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 6),
        ],
      ),
    );
  }

  // ==========================================================
  // COMPOSER
  // ==========================================================

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _msgController,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 13,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),

          const SizedBox(width: 10),

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x221F5D42),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'Enviar',
              onPressed: _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pingTimer?.cancel();

    widget.socket.destroy();

    _msgController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildChatHeader(),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _showMetrics
                ? _buildMetricsPanel()
                : const SizedBox.shrink(),
          ),

          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildChatBackground()),

                Positioned.fill(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 20,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];

                      if (msg.user == 'Sistema') {
                        return _buildSystemMessage(msg);
                      }

                      return _buildUserMessage(context, msg);
                    },
                  ),
                ),
              ],
            ),
          ),

          _buildComposer(),
        ],
      ),
    );
  }
}
