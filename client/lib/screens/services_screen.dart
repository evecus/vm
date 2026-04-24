import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ServicesScreen extends StatefulWidget {
  final ServerConfig server;
  const ServicesScreen({super.key, required this.server});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late ApiService _api;
  List<ServiceInfo> _all = [];
  List<ServiceInfo> _filtered = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  // filter: all / active / inactive / failed
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.server);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _api.getServices();
      if (mounted) {
        setState(() {
          _all = list;
          _loading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _applyFilter() {
    var result = _all;
    if (_filter != 'all') {
      result = result.where((s) => s.activeState == _filter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q))
          .toList();
    }
    _filtered = result;
  }

  // ── Action with confirm dialog ───────────────────────────────
  Future<void> _doAction(ServiceInfo svc, String action) async {
    final labels = {
      'start': '启动', 'stop': '停止', 'restart': '重启',
      'reload': '重载', 'enable': '设为开机启动', 'disable': '取消开机启动',
    };
    final danger = {'stop', 'disable'};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('确认${labels[action]}',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          '确定要 ${labels[action]} ${svc.name} 吗？',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              labels[action]!,
              style: TextStyle(
                  color: danger.contains(action)
                      ? AppTheme.danger
                      : AppTheme.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _api.serviceAction(svc.name, action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${labels[action]} 成功'),
            duration: const Duration(seconds: 2)));
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 3)));
      }
    }
  }

  // ── Create / Edit dialog ─────────────────────────────────────
  Future<void> _showEditDialog({ServiceInfo? existing}) async {
    String? unitContent;
    if (existing != null) {
      try {
        unitContent = await _api.getServiceUnit(existing.name);
      } catch (_) {}
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _ServiceEditSheet(
        api: _api,
        existing: existing,
        initialUnit: unitContent,
        onSaved: () {
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  // ── Delete confirm ───────────────────────────────────────────
  Future<void> _deleteService(ServiceInfo svc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('删除服务',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: Text(
          '确定要删除 ${svc.name} 吗？\n此操作将停止服务并删除 unit 文件，不可恢复。',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteService(svc.name);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppTheme.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top bar ──────────────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              // Search + add
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() { _search = v; _applyFilter(); }),
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: '搜索服务名称...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: AppTheme.textSecondary, size: 18),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        filled: true,
                        fillColor: AppTheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Icon(Icons.refresh,
                          color: AppTheme.textSecondary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showEditDialog(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primary.withOpacity(0.4)),
                      ),
                      child: const Icon(Icons.add,
                          color: AppTheme.primary, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('全部', 'all'),
                    _filterChip('运行中', 'active'),
                    _filterChip('已停止', 'inactive'),
                    _filterChip('失败', 'failed'),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),

        // ── List ─────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 40),
                          const SizedBox(height: 8),
                          Text(_error!,
                              style:
                                  const TextStyle(color: AppTheme.danger)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load,
                              child: const Text('重试')),
                        ],
                      ),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text('没有匹配的服务',
                              style: TextStyle(
                                  color: AppTheme.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) =>
                              _ServiceCard(
                                service: _filtered[i],
                                onAction: (action) =>
                                    _doAction(_filtered[i], action),
                                onEdit: () =>
                                    _showEditDialog(existing: _filtered[i]),
                                onDelete: () =>
                                    _deleteService(_filtered[i]),
                              ),
                        ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () => setState(() { _filter = value; _applyFilter(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? AppTheme.primary.withOpacity(0.5)
                  : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── Service card ─────────────────────────────────────────────────
class _ServiceCard extends StatefulWidget {
  final ServiceInfo service;
  final void Function(String action) onAction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onAction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    Color stateColor;
    IconData stateIcon;
    if (svc.isRunning) {
      stateColor = AppTheme.success;
      stateIcon = Icons.check_circle;
    } else if (svc.isFailed) {
      stateColor = AppTheme.danger;
      stateIcon = Icons.error;
    } else if (svc.activeState == 'inactive') {
      stateColor = AppTheme.textSecondary;
      stateIcon = Icons.stop_circle_outlined;
    } else {
      stateColor = AppTheme.warning;
      stateIcon = Icons.hourglass_bottom;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // ── Header row ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(stateIcon, color: stateColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          svc.name,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (svc.description.isNotEmpty)
                          Text(
                            svc.description,
                            style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // enabled badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: svc.enabled
                          ? AppTheme.success.withOpacity(0.15)
                          : AppTheme.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      svc.enabled ? '自启' : '手动',
                      style: TextStyle(
                          color: svc.enabled
                              ? AppTheme.success
                              : AppTheme.textSecondary,
                          fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded actions ──
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: [
                  // state info row
                  Row(
                    children: [
                      _badge(svc.activeState, stateColor),
                      const SizedBox(width: 6),
                      _badge(svc.subState, AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      _badge(svc.loadState, AppTheme.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // action buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (!svc.isRunning)
                          _actionBtn('启动', Icons.play_arrow,
                              AppTheme.success, () => widget.onAction('start')),
                        if (svc.isRunning)
                          _actionBtn('停止', Icons.stop,
                              AppTheme.danger, () => widget.onAction('stop')),
                        if (svc.isRunning)
                          _actionBtn('重启', Icons.refresh,
                              AppTheme.warning, () => widget.onAction('restart')),
                        if (svc.enabled)
                          _actionBtn('禁用自启', Icons.toggle_off,
                              AppTheme.textSecondary, () => widget.onAction('disable'))
                        else
                          _actionBtn('开机自启', Icons.toggle_on,
                              AppTheme.info, () => widget.onAction('enable')),
                        _actionBtn('编辑', Icons.edit,
                            AppTheme.primary, widget.onEdit),
                        _actionBtn('删除', Icons.delete_outline,
                            AppTheme.danger, widget.onDelete),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10)),
    );
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Service edit/create bottom sheet ─────────────────────────────
class _ServiceEditSheet extends StatefulWidget {
  final ApiService api;
  final ServiceInfo? existing;
  final String? initialUnit;
  final VoidCallback onSaved;

  const _ServiceEditSheet({
    required this.api,
    required this.existing,
    required this.initialUnit,
    required this.onSaved,
  });

  @override
  State<_ServiceEditSheet> createState() => _ServiceEditSheetState();
}

class _ServiceEditSheetState extends State<_ServiceEditSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _execCtrl = TextEditingController();
  final _wdCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  String _restart = 'on-failure';
  String _wantedBy = 'multi-user.target';

  // Raw unit editor
  final _rawCtrl = TextEditingController();
  bool _useRaw = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name.replaceAll('.service', '');
      _descCtrl.text = widget.existing!.description;
    }
    if (widget.initialUnit != null) {
      _rawCtrl.text = widget.initialUnit!;
      _parseUnit(widget.initialUnit!);
    }
  }

  void _parseUnit(String content) {
    for (final line in content.split('\n')) {
      final kv = line.split('=');
      if (kv.length < 2) continue;
      final key = kv[0].trim();
      final val = kv.sublist(1).join('=').trim();
      switch (key) {
        case 'Description': _descCtrl.text = val; break;
        case 'ExecStart':   _execCtrl.text = val; break;
        case 'WorkingDirectory': _wdCtrl.text = val; break;
        case 'User':        _userCtrl.text = val; break;
        case 'Restart':     _restart = val; break;
        case 'WantedBy':    _wantedBy = val; break;
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final isEdit = widget.existing != null;
      if (_useRaw) {
        // Save raw unit directly via write file API
        final name = _nameCtrl.text.trim().replaceAll('.service', '');
        final path = '/etc/systemd/system/$name.service';
        await widget.api.writeFile(path, _rawCtrl.text);
        // daemon-reload via action trick: create a dummy then delete — instead
        // just call update endpoint with raw flag if we add that later.
        // For now the writeFile + daemon-reload on server side isn't automatic
        // so we use the structured endpoint anyway and note this limitation.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('已保存，请手动运行 systemctl daemon-reload'),
              duration: Duration(seconds: 3)));
      } else {
        final data = {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'execStart': _execCtrl.text.trim(),
          'workingDir': _wdCtrl.text.trim(),
          'user': _userCtrl.text.trim(),
          'restart': _restart,
          'wantedBy': _wantedBy,
        };
        if (isEdit) {
          await widget.api.updateService(_nameCtrl.text.trim(), data);
        } else {
          await widget.api.createService(data);
        }
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppTheme.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    isEdit ? '编辑服务' : '新建服务',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primary))
                        : const Text('保存',
                            style: TextStyle(color: AppTheme.primary)),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [Tab(text: '表单'), Tab(text: '原始 Unit')],
            ),
            Flexible(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _formTab(),
                  _rawTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field('服务名称', _nameCtrl, '如: myapp',
            enabled: widget.existing == null),
        _field('描述', _descCtrl, '简短描述（可选）'),
        _field('启动命令', _execCtrl, '如: /usr/bin/node /app/index.js'),
        _field('工作目录', _wdCtrl, '如: /opt/myapp（可选）'),
        _field('运行用户', _userCtrl, '如: www-data（留空则 root）'),
        const SizedBox(height: 8),
        _dropRow('重启策略', _restart, [
          'no', 'on-success', 'on-failure', 'on-abnormal',
          'on-abort', 'always'
        ], (v) => setState(() => _restart = v!)),
        _dropRow('WantedBy', _wantedBy, [
          'multi-user.target', 'graphical.target', 'network.target'
        ], (v) => setState(() => _wantedBy = v!)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _rawTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Text('直接编辑 unit 文件',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _useRaw,
                onChanged: (v) => setState(() => _useRaw = v),
                activeColor: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _rawCtrl,
              enabled: _useRaw,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono'),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.border)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          hintStyle:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          isDense: true,
          filled: true,
          fillColor: AppTheme.surfaceVariant,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border)),
        ),
      ),
    );
  }

  Widget _dropRow(String label, String value, List<String> options,
      void Function(String?) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              dropdownColor: AppTheme.surface,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppTheme.border)),
              ),
              items: options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                  .toList(),
              onChanged: onChange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _execCtrl.dispose();
    _wdCtrl.dispose();
    _userCtrl.dispose();
    _rawCtrl.dispose();
    super.dispose();
  }
}
