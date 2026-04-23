import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/server_storage.dart';
import '../services/api_service.dart';
import '../theme.dart';

class AddServerScreen extends StatefulWidget {
  final ServerConfig? server;
  const AddServerScreen({super.key, this.server});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;
  late TextEditingController _tokenCtrl;
  bool _useTLS = false;
  bool _testing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.server;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _hostCtrl = TextEditingController(text: s?.host ?? '');
    _portCtrl = TextEditingController(text: s?.port ?? '8888');
    _tokenCtrl = TextEditingController(text: s?.token ?? '');
    _useTLS = s?.useTLS ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _testing = true);
    final server = ServerConfig(
      id: widget.server?.id ?? ServerStorage.generateId(),
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: _portCtrl.text.trim(),
      token: _tokenCtrl.text.trim(),
      useTLS: _useTLS,
    );
    final api = ApiService(server);
    final ok = await api.verify();
    setState(() => _testing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✓ 连接成功' : '✗ 连接失败，请检查配置'),
      backgroundColor: ok ? AppTheme.success : AppTheme.danger,
    ));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final server = ServerConfig(
      id: widget.server?.id ?? ServerStorage.generateId(),
      name: _nameCtrl.text.trim(),
      host: _hostCtrl.text.trim(),
      port: _portCtrl.text.trim(),
      token: _tokenCtrl.text.trim(),
      useTLS: _useTLS,
    );
    if (widget.server != null) {
      await ServerStorage.update(server);
    } else {
      await ServerStorage.add(server);
    }
    setState(() => _saving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.server != null ? '编辑服务器' : '添加服务器'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field('名称', _nameCtrl, hint: '我的 VPS', icon: Icons.label),
              const SizedBox(height: 16),
              _field('主机 / 域名', _hostCtrl,
                  hint: '1.2.3.4 或 vps.example.com', icon: Icons.computer),
              const SizedBox(height: 16),
              _field('端口', _portCtrl,
                  hint: '8888',
                  icon: Icons.settings_ethernet,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              _field('Token', _tokenCtrl,
                  hint: 'your-secret-token',
                  icon: Icons.key,
                  obscure: true),
              const SizedBox(height: 16),
              // TLS toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: AppTheme.textSecondary, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('启用 HTTPS / TLS',
                              style: TextStyle(color: AppTheme.textPrimary)),
                          Text('使用 wss:// 和 https://',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _useTLS,
                      onChanged: (v) => setState(() => _useTLS = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Buttons
              OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? '测试中...' : '测试连接'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.background))
                    : const Icon(Icons.save),
                label: Text(_saving ? '保存中...' : '保存'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    String? hint,
    IconData? icon,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, color: AppTheme.textSecondary, size: 20)
            : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '$label 不能为空';
        return null;
      },
    );
  }
}
