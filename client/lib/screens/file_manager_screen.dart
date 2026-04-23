import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'editor_screen.dart';

class FileManagerScreen extends StatefulWidget {
  final ServerConfig server;
  const FileManagerScreen({super.key, required this.server});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  late ApiService _api;
  String _currentPath = '/';
  List<FileItem> _items = [];
  bool _loading = true;
  String? _error;
  final List<String> _pathStack = ['/'];

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.server);
    _loadPath('/');
  }

  Future<void> _loadPath(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.listFiles(path);
      setState(() {
        _currentPath = result['path'] as String;
        _items = result['items'] as List<FileItem>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _navigate(FileItem item) {
    if (item.isDir) {
      _pathStack.add(item.path);
      _loadPath(item.path);
    } else {
      _showFileActions(item);
    }
  }

  bool _canGoBack() => _pathStack.length > 1;

  void _goBack() {
    if (_canGoBack()) {
      _pathStack.removeLast();
      _loadPath(_pathStack.last);
    }
  }

  void _showFileActions(FileItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => _FileActionsSheet(
        item: item,
        api: _api,
        onRefresh: () => _loadPath(_currentPath),
        onEdit: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorScreen(server: widget.server, path: item.path),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createFolder() async {
    final name = await _showInputDialog('新建文件夹', '文件夹名称');
    if (name == null || name.isEmpty) return;
    try {
      await _api.mkdir(p.join(_currentPath, name));
      _loadPath(_currentPath);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _createFile() async {
    final name = await _showInputDialog('新建文件', '文件名称');
    if (name == null || name.isEmpty) return;
    try {
      await _api.touch(p.join(_currentPath, name));
      _loadPath(_currentPath);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primary),
            SizedBox(width: 16),
            Text('上传中...'),
          ],
        ),
      ),
    );

    try {
      await _api.uploadFile(_currentPath, file.path!);
      if (mounted) Navigator.pop(context);
      _loadPath(_currentPath);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError(e.toString());
    }
  }

  Future<String?> _showInputDialog(String title, String hint,
      {String? initial}) async {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('确定')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildPathBar(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? _buildError()
                    : _items.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppTheme.primary,
                            onRefresh: () => _loadPath(_currentPath),
                            child: ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (ctx, i) =>
                                  _buildFileItem(_items[i]),
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPathBar() {
    final parts = _currentPath.split('/').where((s) => s.isNotEmpty).toList();
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: _canGoBack() ? _goBack : null,
            color: _canGoBack() ? AppTheme.primary : AppTheme.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _pathStack.clear();
                      _pathStack.add('/');
                      _loadPath('/');
                    },
                    child: const Text('/',
                        style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                  ),
                  ...parts.asMap().entries.map((e) {
                    final idx = e.key;
                    final part = e.value;
                    final fullPath =
                        '/' + parts.sublist(0, idx + 1).join('/');
                    final isLast = idx == parts.length - 1;
                    return Row(
                      children: [
                        const Text(' / ',
                            style: TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                        GestureDetector(
                          onTap: isLast
                              ? null
                              : () {
                                  while (_pathStack.last != fullPath &&
                                      _pathStack.length > 1) {
                                    _pathStack.removeLast();
                                  }
                                  _loadPath(fullPath);
                                },
                          child: Text(
                            part,
                            style: TextStyle(
                              color: isLast
                                  ? AppTheme.textPrimary
                                  : AppTheme.primary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _loadPath(_currentPath),
            color: AppTheme.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, size: 20),
            onPressed: _uploadFile,
            color: AppTheme.textSecondary,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(FileItem item) {
    return InkWell(
      onTap: () => _navigate(item),
      onLongPress: () => _showFileActions(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(
          children: [
            _fileIcon(item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        item.formattedSize,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.mode,
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                      if (item.isSymlink) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.link,
                            size: 11, color: AppTheme.textSecondary),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _formatDate(item.modTime),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _fileIcon(FileItem item) {
    if (item.isDir) {
      return const Icon(Icons.folder, color: Color(0xFFFBBF24), size: 28);
    }
    final ext = p.extension(item.name).toLowerCase();
    IconData icon;
    Color color;
    switch (ext) {
      case '.sh':
      case '.bash':
        icon = Icons.terminal;
        color = AppTheme.success;
        break;
      case '.py':
        icon = Icons.code;
        color = const Color(0xFF3B82F6);
        break;
      case '.go':
        icon = Icons.code;
        color = const Color(0xFF06B6D4);
        break;
      case '.js':
      case '.ts':
        icon = Icons.javascript;
        color = const Color(0xFFF59E0B);
        break;
      case '.json':
      case '.yaml':
      case '.yml':
      case '.toml':
        icon = Icons.data_object;
        color = AppTheme.primary;
        break;
      case '.conf':
      case '.cfg':
      case '.ini':
        icon = Icons.settings;
        color = AppTheme.textSecondary;
        break;
      case '.log':
        icon = Icons.list_alt;
        color = AppTheme.warning;
        break;
      case '.gz':
      case '.zip':
      case '.tar':
      case '.xz':
        icon = Icons.archive;
        color = AppTheme.warning;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = AppTheme.textSecondary;
    }
    return Icon(icon, color: color, size: 28);
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day}';
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppTheme.danger)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: () => _loadPath(_currentPath),
              child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, color: AppTheme.textSecondary, size: 48),
          SizedBox(height: 12),
          Text('空目录', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder,
                  color: Color(0xFFFBBF24)),
              title: const Text('新建文件夹'),
              onTap: () {
                Navigator.pop(ctx);
                _createFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_add, color: AppTheme.primary),
              title: const Text('新建文件'),
              onTap: () {
                Navigator.pop(ctx);
                _createFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file, color: AppTheme.info),
              title: const Text('上传文件'),
              onTap: () {
                Navigator.pop(ctx);
                _uploadFile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── File Actions Bottom Sheet ────────────────────────────────────────────────

class _FileActionsSheet extends StatelessWidget {
  final FileItem item;
  final ApiService api;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;

  const _FileActionsSheet({
    required this.item,
    required this.api,
    required this.onRefresh,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isTextFile = _isText(item.name);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary)),
                      Text(item.formattedSize,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isTextFile)
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primary),
              title: const Text('编辑'),
              onTap: onEdit,
            ),
          ListTile(
            leading: const Icon(Icons.download, color: AppTheme.info),
            title: const Text('下载'),
            onTap: () async {
              Navigator.pop(context);
              final url = api.downloadUrl(item.path);
              // Launch download URL
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('下载链接: $url')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline,
                color: AppTheme.warning),
            title: const Text('重命名'),
            onTap: () async {
              Navigator.pop(context);
              final dir = p.dirname(item.path);
              final ctrl = TextEditingController(text: item.name);
              final newName = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('重命名'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(hintText: '新名称'),
                    onSubmitted: (v) => Navigator.pop(ctx, v),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, ctrl.text),
                        child: const Text('确定')),
                  ],
                ),
              );
              if (newName != null && newName.isNotEmpty) {
                await api.rename(item.path, p.join(dir, newName));
                onRefresh();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: AppTheme.danger),
            title: const Text('删除', style: TextStyle(color: AppTheme.danger)),
            onTap: () async {
              Navigator.pop(context);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除确认'),
                  content: Text('确定删除 ${item.name}？此操作不可恢复。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.danger),
                        child: const Text('删除')),
                  ],
                ),
              );
              if (ok == true) {
                await api.delete(item.path);
                onRefresh();
              }
            },
          ),
        ],
      ),
    );
  }

  bool _isText(String name) {
    final ext = p.extension(name).toLowerCase();
    const textExts = {
      '.txt', '.md', '.sh', '.bash', '.py', '.go', '.js', '.ts',
      '.json', '.yaml', '.yml', '.toml', '.conf', '.cfg', '.ini',
      '.env', '.log', '.xml', '.html', '.css', '.rs', '.c', '.cpp',
      '.h', '.java', '.rb', '.php', '.sql', '.service', '.timer',
      '.nginx', '.htaccess', '',
    };
    return textExts.contains(ext);
  }
}
