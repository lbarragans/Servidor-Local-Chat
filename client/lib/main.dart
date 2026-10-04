import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chat Local TCP',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
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
// PANTALLA DE CONEXIÓN
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso al Chat')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Dirección IP del servidor',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puerto',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _userController,
              decoration: const InputDecoration(
                labelText: 'Nombre de Usuario',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _connect,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Conectar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PANTALLA DEL CHAT
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

  // ==========================================================
  // MÉTRICAS DE RED
  // ==========================================================

  double _latencyMs = 0.0;
  double _jitterMs = 0.0;
  double? _previousLatencyMs;

  // ==========================================================
  // MÉTRICAS DEL SERVIDOR
  // ==========================================================

  double _cpuPercent = 0.0;
  int _memoryBytes = 0;
  int _connectedUsers = 0;

  int _receivedMessages = 0;

  bool _connected = true;

  // Control del panel desplegable.
  bool _showMetrics = true;

  @override
  void initState() {
    super.initState();

    _listenSocket();
    _startMetrics();
  }

  // ==========================================================
  // PING
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

  // ==========================================================
  // RECEPCIÓN
  // ==========================================================

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

              // ---------------------------------------------------
              // PONG
              // ---------------------------------------------------

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

              // ---------------------------------------------------
              // MENSAJE
              // ---------------------------------------------------

              if (event.type == 'message') {
                if (!mounted) return;

                setState(() {
                  _messages.add(event);
                  _receivedMessages++;
                });

                _scrollToBottom();
              }
              // ---------------------------------------------------
              // ERROR
              // ---------------------------------------------------
              else if (event.type == 'error') {
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚠️ Error: ${event.text}')),
                );
              }
            } catch (_) {
              // Ignorar paquetes inválidos.
            }
          },
          onDone: _handleDisconnect,
          onError: (_) => _handleDisconnect(),
        );
  }

  // ==========================================================
  // ENVÍO
  // ==========================================================

  void _sendMessage() {
    final text = _msgController.text.trim();

    if (text.isEmpty) return;

    final req = Request(type: 'message', user: widget.username, text: text);

    widget.socket.writeln(jsonEncode(req.toJson()));

    _msgController.clear();
  }

  // ==========================================================
  // DESCONEXIÓN
  // ==========================================================

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

  // ==========================================================
  // SCROLL
  // ==========================================================

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
  // FORMATOS
  // ==========================================================

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';

    final d = dt.day.toString().padLeft(2, '0');

    final m = dt.month.toString().padLeft(2, '0');

    final y = dt.year;

    final hh = dt.hour.toString().padLeft(2, '0');

    final mm = dt.minute.toString().padLeft(2, '0');

    final ss = dt.second.toString().padLeft(2, '0');

    return '$d/$m/$y $hh:$mm:$ss';
  }

  String _formatMemory(int bytes) {
    if (bytes <= 0) {
      return 'Midiendo...';
    }

    final mb = bytes / (1024 * 1024);

    return '${mb.toStringAsFixed(1)} MB';
  }

  // ==========================================================
  // ITEM MÉTRICA
  // ==========================================================

  Widget _metricItem(
    IconData icon,
    String title,
    String value, {
    Color? iconColor,
  }) {
    return SizedBox(
      width: 175,
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? Colors.indigo, size: 25),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // PANEL DE MÉTRICAS
  // ==========================================================

  Widget _buildMetricsPanel() {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

      decoration: BoxDecoration(
        color: Colors.indigo.shade50,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.indigo.shade100),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: Colors.indigo,
              ),

              const SizedBox(width: 8),

              const Expanded(
                child: Text(
                  'Métricas del sistema',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),

              // Botón interno para cerrar el panel.
              IconButton(
                tooltip: 'Cerrar panel',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _showMetrics = false;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ---------------------------------------------------
          // RED
          // ---------------------------------------------------
          const Text(
            'Red cliente-servidor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              _metricItem(
                Icons.circle,
                'Estado',
                _connected ? 'Conectado' : 'Desconectado',
                iconColor: _connected ? Colors.green : Colors.red,
              ),

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
                Icons.message_outlined,
                'Mensajes recibidos',
                '$_receivedMessages',
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Divider(),

          const SizedBox(height: 8),

          // ---------------------------------------------------
          // SERVIDOR
          // ---------------------------------------------------
          const Text(
            'Servidor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 20,
            runSpacing: 14,
            children: [
              _metricItem(
                Icons.memory,
                'CPU servidor',
                '${_cpuPercent.toStringAsFixed(2)} %',
              ),

              _metricItem(
                Icons.storage_outlined,
                'Memoria servidor',
                _formatMemory(_memoryBytes),
              ),

              _metricItem(
                Icons.people_outline,
                'Usuarios conectados',
                '$_connectedUsers',
              ),

              _metricItem(Icons.dns_outlined, 'IP servidor', widget.serverIp),

              _metricItem(
                Icons.settings_ethernet,
                'Puerto',
                '${widget.serverPort}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    _pingTimer?.cancel();

    widget.socket.destroy();

    _msgController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ==========================================================
  // INTERFAZ
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.username}'),

        actions: [
          // Botón para mostrar u ocultar las métricas.
          IconButton(
            tooltip: _showMetrics ? 'Ocultar métricas' : 'Ver métricas',

            icon: Icon(
              _showMetrics ? Icons.monitor_heart : Icons.monitor_heart_outlined,
            ),

            onPressed: () {
              setState(() {
                _showMetrics = !_showMetrics;
              });
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          // ===================================================
          // PANEL DESPLEGABLE
          // ===================================================

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),

            child: _showMetrics
                ? _buildMetricsPanel()
                : const SizedBox.shrink(),
          ),

          // ===================================================
          // CHAT
          // ===================================================
          Expanded(
            child: ListView.builder(
              controller: _scrollController,

              padding: const EdgeInsets.all(12),

              itemCount: _messages.length,

              itemBuilder: (context, index) {
                final msg = _messages[index];

                final isMe = msg.user == widget.username;

                final isSystem = msg.user == 'Sistema';

                // ------------------------------------------------
                // MENSAJE DEL SISTEMA
                // ------------------------------------------------

                if (isSystem) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),

                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Text(
                        msg.text,

                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }

                // ------------------------------------------------
                // MENSAJE DE USUARIO
                // ------------------------------------------------

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,

                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),

                    padding: const EdgeInsets.all(12),

                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),

                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.indigo.shade100
                          : Colors.grey.shade200,

                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Text(
                          msg.user,

                          style: TextStyle(
                            fontWeight: FontWeight.bold,

                            fontSize: 12,

                            color: isMe
                                ? Colors.indigo.shade900
                                : Colors.black87,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(msg.text, style: const TextStyle(fontSize: 15)),

                        const SizedBox(height: 4),

                        Text(
                          _formatDate(msg.time),

                          style: TextStyle(
                            fontSize: 10,

                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ===================================================
          // ENTRADA DEL CHAT
          // ===================================================
          Padding(
            padding: const EdgeInsets.all(8),

            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,

                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',

                      border: OutlineInputBorder(),
                    ),

                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton.filled(
                  icon: const Icon(Icons.send),

                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
