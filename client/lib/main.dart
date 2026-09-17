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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const ConnectScreen(),
    );
  }
}

// Modelos de datos
class Request {
  final String type;
  final String user;
  final String? text;

  Request({required this.type, required this.user, this.text});

  Map<String, dynamic> toJson() => {
        'type': type,
        'user': user,
        if (text != null) 'text': text,
      };
}

class Event {
  final String type;
  final int? id;
  final String user;
  final String text;
  final DateTime? time;

  Event({
    required this.type,
    this.id,
    required this.user,
    required this.text,
    this.time,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      type: json['type'] ?? '',
      id: json['id'],
      user: json['user'] ?? 'Sistema',
      text: json['text'] ?? '',
      time: json['time'] != null ? DateTime.parse(json['time']).toLocal() : null,
    );
  }
}

// Pantalla 1: Formulario de Conexión
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

    setState(() => _isLoading = true);

    try {
      final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      
      // Enviar el evento "join" inmediatamente al servidor
      final joinReq = Request(type: 'join', user: username);
      socket.writeln(jsonEncode(joinReq.toJson()));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            socket: socket,
            username: username,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de conexión: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso al Chat')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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

// Pantalla 2: Interfaz de Chat
class ChatScreen extends StatefulWidget {
  final Socket socket;
  final String username;

  const ChatScreen({
    super.key,
    required this.socket,
    required this.username,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Event> _messages = [];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _listenSocket();
  }

  void _listenSocket() {
    // Se agrega .cast<List<int>>() para compatibilidad de tipos con utf8.decoder
    widget.socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.trim().isEmpty) return;
        try {
          final Map<String, dynamic> jsonMap = jsonDecode(line);
          final event = Event.fromJson(jsonMap);

          if (event.type == 'message') {
            setState(() {
              _messages.add(event);
            });
            _scrollToBottom();
          } else if (event.type == 'error') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('⚠️ Error: ${event.text}')),
            );
          }
        } catch (_) {}
      },
      onDone: () => _handleDisconnect(),
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

  @override
  void dispose() {
    widget.socket.destroy();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat: ${widget.username}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.user == widget.username;
                final isSystem = msg.user == 'Sistema';

                if (isSystem) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        msg.text,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.indigo.shade100 : Colors.grey.shade200,
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
                            color: isMe ? Colors.indigo.shade900 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(msg.text, style: const TextStyle(fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(msg.time),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
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