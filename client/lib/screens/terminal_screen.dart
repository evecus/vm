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

  // Whether the Ctrl modifier is latched (sticky)
  bool _ctrlActive = false;

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
      _ctrlActive = false;
    });

    _terminal = Terminal(maxLines: 10000);
    _terminalController = TerminalController();

    _terminal!.onOutput = (data) {
      if (_channel != null) {
        _channel!.sink.add(utf8.encode(data));
      }
    };

    _terminal!.onResize = (w, h, pw, ph) {
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
          String text;
          if (data is String) {
            text = data;
          } else if (data is List<int>) {
            text = utf8.decode(data, allowMalformed: true);
          } else if (data is Uint8List) {
            text = utf8.decode(data, allowMalformed: true);
          } else {
            return;
          }
          // Filter out control JSON messages (e.g. resize echoes from server)
          final trimmed = text.trimLeft();
          if (trimmed.startsWith('{') && trimmed.contains('"type"')) {
            try {
              final msg = jsonDecode(trimmed);
              if (msg is Map && msg.containsKey('type')) return;
            } catch (_) {}
          }
          _terminal!.write(text);
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
              if (_error == null) _error = '连接已断开';
            });
          }
        },
      );

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

  // Send raw bytes to the server
  void _sendBytes(List<int> bytes) {
    _channel?.sink.add(Uint8List.fromList(bytes));
  }

  void _sendCmd(String cmd) {
    _channel?.sink.add(utf8.encode(cmd));
  }

  // Handle a key from the virtual keyboard.
  // If Ctrl is latched, combine it with the key first.
  void _handleVirtualKey(String chars) {
    if (_ctrlActive) {
      // Compute Ctrl+char: byte = charCode & 0x1F
      final ch = chars.toLowerCase().codeUnitAt(0);
      _sendBytes([ch & 0x1F]);
      setState(() => _ctrlActive = false);
    } else {
      _sendCmd(chars);
    }
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
        // ── Top toolbar ──────────────────────────────────────────
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

        // ── Terminal view ────────────────────────────────────────
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

        // ── Virtual key bar ──────────────────────────────────────
        _VirtualKeyBar(
          ctrlActive: _ctrlActive,
          onCtrlToggle: () => setState(() => _ctrlActive = !_ctrlActive),
          onKey: _handleVirtualKey,
          onSpecial: _sendBytes,
        ),
      ],
    );
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

// ────────────────────────────────────────────────────────────────
// Virtual keyboard bar
// ────────────────────────────────────────────────────────────────
class _VirtualKeyBar extends StatelessWidget {
  final bool ctrlActive;
  final VoidCallback onCtrlToggle;
  final void Function(String chars) onKey;
  final void Function(List<int> bytes) onSpecial;

  const _VirtualKeyBar({
    required this.ctrlActive,
    required this.onCtrlToggle,
    required this.onKey,
    required this.onSpecial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // ── Ctrl (sticky modifier) ──
            _ModKey(
              label: 'Ctrl',
              active: ctrlActive,
              onTap: onCtrlToggle,
            ),
            const SizedBox(width: 4),
            const _Divider(),
            // ── Ctrl combos ──
            _VKey('C', () => onSpecial([0x03])),   // Ctrl+C  ETX
            _VKey('D', () => onSpecial([0x04])),   // Ctrl+D  EOT
            _VKey('Z', () => onSpecial([0x1A])),   // Ctrl+Z  SUB
            _VKey('L', () => onSpecial([0x0C])),   // Ctrl+L  clear screen
            _VKey('A', () => onSpecial([0x01])),   // Ctrl+A  line start
            _VKey('E', () => onSpecial([0x05])),   // Ctrl+E  line end
            _VKey('U', () => onSpecial([0x15])),   // Ctrl+U  kill line
            _VKey('W', () => onSpecial([0x17])),   // Ctrl+W  delete word
            _VKey('R', () => onSpecial([0x12])),   // Ctrl+R  history search
            const _Divider(),
            // ── Navigation ──
            _VKey('ESC', () => onSpecial([0x1B])),
            _VKey('Tab', () => onSpecial([0x09])),
            _VKey('↑', () => onSpecial([0x1B, 0x5B, 0x41])),
            _VKey('↓', () => onSpecial([0x1B, 0x5B, 0x42])),
            _VKey('←', () => onSpecial([0x1B, 0x5B, 0x44])),
            _VKey('→', () => onSpecial([0x1B, 0x5B, 0x43])),
            const _Divider(),
            // ── Editing ──
            _VKey('Del', () => onSpecial([0x7F])),   // Backspace / DEL
            _VKey('|', () => onKey('|')),
            _VKey('~', () => onKey('~')),
            _VKey('/', () => onKey('/')),
            _VKey('-', () => onKey('-')),
            _VKey('_', () => onKey('_')),
          ],
        ),
      ),
    );
  }
}

class _VKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _VKey(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ),
    );
  }
}

class _ModKey extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModKey({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.2) : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.primary : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'JetBrains Mono',
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: AppTheme.border,
    );
  }
}
