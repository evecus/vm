import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/server_storage.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'add_server_screen.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen> {
  List<ServerConfig> _servers = [];
  final Map<String, bool> _pingResults = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final servers = await ServerStorage.loadAll();
    setState(() => _servers = servers);
    _pingAll();
  }

  Future<void> _pingAll() async {
    for (final s in _servers) {
      final api = ApiService(s);
      final ok = await api.verify();
      if (mounted) {
        setState(() => _pingResults[s.id] = ok);
      }
    }
  }

  void _connect(ServerConfig server) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(server: server)),
    ).then((_) => _load());
  }

  Future<void> _delete(ServerConfig server) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除服务器'),
        content: Text('确定删除 ${server.name}？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ServerStorage.remove(server.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.dns, color: AppTheme.background, size: 16),
            ),
            const SizedBox(width: 10),
            const Text('VPS Manager'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _pingAll,
            tooltip: '刷新状态',
          ),
        ],
      ),
      body: _servers.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _pingAll,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _servers.length,
                itemBuilder: (ctx, i) => _buildServerCard(_servers[i]),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddServerScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('添加服务器'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(Icons.cloud_off, size: 40, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          const Text(
            '暂无服务器',
            style: TextStyle(fontSize: 18, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角按钮添加 VPS',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(ServerConfig server) {
    final isOnline = _pingResults[server.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline == true
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _connect(server),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status indicator
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOnline == null
                            ? AppTheme.warning
                            : isOnline
                                ? AppTheme.success
                                : AppTheme.danger,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        server.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    // TLS badge
                    if (server.useTLS)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppTheme.success.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'TLS',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.success),
                        ),
                      ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppTheme.textSecondary, size: 20),
                      onSelected: (val) async {
                        if (val == 'edit') {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddServerScreen(server: server),
                            ),
                          );
                          _load();
                        } else if (val == 'delete') {
                          _delete(server);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit, size: 16),
                            SizedBox(width: 8),
                            Text('编辑'),
                          ]),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, size: 16, color: AppTheme.danger),
                            SizedBox(width: 8),
                            Text('删除',
                                style: TextStyle(color: AppTheme.danger)),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.computer, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '${server.host}:${server.port}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      isOnline == null
                          ? '检测中...'
                          : isOnline
                              ? '在线'
                              : '离线',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline == null
                            ? AppTheme.warning
                            : isOnline
                                ? AppTheme.success
                                : AppTheme.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
