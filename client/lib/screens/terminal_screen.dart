import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';
import '../models/models.dart';
import '../theme.dart';

class TerminalScreen extends StatefulWidget {
  final ServerConfig server;
  const TerminalScreen({super.key, required this.server});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen>
    with AutomaticKeepAliveClientMixin {
  Terminal? _terminal;
  TerminalController? _terminalController;
  WebSocketChannel? _channel;
  bool _connected = false;
  bool _connecting = false;
  String? _error;
  StreamSubscription? _sub;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  void _connect() {
    setState(() {
      _connecting = true;
      _error = null;
    });

    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();

    _terminal!.onOutput = (data) {
      // Send input from terminal to WebSocket
      if (_channel != null) {
        _channel!.sink.add(utf8.encode(data));
      }
    };

    _terminal!.onResize = (w, h, pw, ph) {
      // Send resize event
      if (_channel != null) {
        final msg = jsonEncode({'type': 'resize', 'cols': w, 'rows': h});
        _channel!.sink.add(utf8.encode(msg));
      }
    };

    final wsUrl =
        '${widget.server.wsUrl}/ws/terminal?token=${widget.server.token}';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        (data) {
          if (!mounted) return;
          if (data is String) {
            _terminal!.write(data);
          } else if (data is List<int>) {
            _terminal!.write(utf8.decode(data, allowMalformed: true));
          } else if (data is Uint8List) {
            _terminal!.write(utf8.decode(data, allowMalformed: true));
          }
          if (!_connected) {
            setState(() {
              _connected = true;
              _connecting = false;
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _connected = false;
              _connecting = false;
              _error = e.toString();
            });
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _connected = false;
              _connecting = false;
              if (_error == null) {
                _error = '连接已断开';
              }
            });
          }
        },
      );

      // Mark connected after a short delay if no error
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _connecting) {
          setState(() {
            _connected = true;
            _connecting = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  void _disconnect() {
    _sub?.cancel();
    _channel?.sink.close();
    _terminal = null;
    _terminalController = null;
  }

  void _reconnect() {
    _disconnect();
    _connect();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_connecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(height: 16),
            Text('正在连接终端...', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    if (_error != null || !_connected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terminal, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text(
              _error ?? '连接失败',
              style: const TextStyle(color: AppTheme.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _reconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('重新连接'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Toolbar
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.circle, color: AppTheme.success, size: 10),
              const SizedBox(width: 6),
              Text(
                widget.server.host,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
              const Spacer(),
              // Quick commands
              _quickBtn('clear', () => _sendCmd('clear\n')),
              _quickBtn('top', () => _sendCmd('top\n')),
              _quickBtn('df -h', () => _sendCmd('df -h\n')),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh,
                    size: 18, color: AppTheme.textSecondary),
                onPressed: _reconnect,
                tooltip: '重新连接',
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        // Terminal
        Expanded(
          child: TerminalView(
            _terminal!,
            controller: _terminalController!,
            theme: const TerminalTheme(
              cursor: Color(0xFF00D4AA),
              selection: Color(0x4000D4AA),
              foreground: Color(0xFFE2E8F0),
              background: Color(0xFF0A0E1A),
              black: Color(0xFF1A2235),
              red: Color(0xFFEF4444),
              green: Color(0xFF10B981),
              yellow: Color(0xFFF59E0B),
              blue: Color(0xFF3B82F6),
              magenta: Color(0xFF8B5CF6),
              cyan: Color(0xFF06B6D4),
              white: Color(0xFFE2E8F0),
              brightBlack: Color(0xFF374151),
              brightRed: Color(0xFFF87171),
              brightGreen: Color(0xFF34D399),
              brightYellow: Color(0xFFFBBF24),
              brightBlue: Color(0xFF60A5FA),
              brightMagenta: Color(0xFFA78BFA),
              brightCyan: Color(0xFF22D3EE),
              brightWhite: Color(0xFFF9FAFB),
              searchHitBackground: Color(0xFF4400D4AA),
              searchHitBackgroundCurrent: Color(0xFF8800D4AA),
              searchHitForeground: Color(0xFF0A0E1A),
            ),
            textStyle: const TerminalStyle(
              fontSize: 13,
              fontFamily: 'JetBrains Mono',
            ),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  void _sendCmd(String cmd) {
    _channel?.sink.add(utf8.encode(cmd));
  }

  Widget _quickBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 11),
        ),
      ),
    );
  }
}
