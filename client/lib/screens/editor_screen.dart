import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class EditorScreen extends StatefulWidget {
  final ServerConfig server;
  final String path;

  const EditorScreen({super.key, required this.server, required this.path});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late ApiService _api;
  late TextEditingController _ctrl;
  bool _loading = true;
  bool _saving = false;
  bool _modified = false;
  String? _error;
  String _originalContent = '';

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.server);
    _ctrl = TextEditingController();
    _ctrl.addListener(() {
      if (!_modified && _ctrl.text != _originalContent) {
        setState(() => _modified = true);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final content = await _api.readFile(widget.path);
      setState(() {
        _ctrl.text = content;
        _originalContent = content;
        _loading = false;
        _modified = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.writeFile(widget.path, _ctrl.text);
      setState(() {
        _saving = false;
        _modified = false;
        _originalContent = _ctrl.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ 保存成功'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_modified) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('未保存的更改'),
        content: const Text('文件有未保存的更改，确定要退出吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('放弃更改'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, false);
              await _save();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('保存并退出'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  String get _fileName => widget.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _fileName,
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (_modified) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                widget.path,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            // Undo
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '撤销',
              onPressed: () {
                _ctrl.value = _ctrl.value.copyWith(
                  text: _originalContent,
                  selection: TextSelection.collapsed(
                      offset: _originalContent.length),
                );
                setState(() => _modified = false);
              },
            ),
            // Save
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.save,
                  color: _modified ? AppTheme.primary : AppTheme.textSecondary,
                ),
                tooltip: '保存 (Ctrl+S)',
                onPressed: _modified ? _save : null,
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary))
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppTheme.danger)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                            onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  )
                : _buildEditor(),
        bottomNavigationBar: _loading || _error != null
            ? null
            : Container(
                color: AppTheme.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '行数: ${_ctrl.text.split('\n').length}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '字符: ${_ctrl.text.length}',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      _modified ? '● 未保存' : '已保存',
                      style: TextStyle(
                        color: _modified
                            ? AppTheme.warning
                            : AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEditor() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers
        _LineNumbers(controller: _ctrl),
        // Editor
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 52,
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  isDense: true,
                  filled: false,
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LineNumbers extends StatefulWidget {
  final TextEditingController controller;
  const _LineNumbers({required this.controller});

  @override
  State<_LineNumbers> createState() => _LineNumbersState();
}

class _LineNumbersState extends State<_LineNumbers> {
  int _lineCount = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final count =
        '\n'.allMatches(widget.controller.text).length + 1;
    if (count != _lineCount) {
      setState(() => _lineCount = count);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      color: AppTheme.surface,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          _lineCount,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${i + 1}',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
