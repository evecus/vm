import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ProcessScreen extends StatefulWidget {
  final ServerConfig server;
  const ProcessScreen({super.key, required this.server});

  @override
  State<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends State<ProcessScreen> {
  late ApiService _api;
  List<ProcessInfo> _all = [];
  List<ProcessInfo> _filtered = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  String _sortBy = 'cpu';
  bool _sortDesc = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.server);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final procs = await _api.getProcesses();
      if (!mounted) return;
      setState(() {
        _all = procs;
        _applyFilter();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    var list = _all.where((p) {
      if (_search.isEmpty) return true;
      return p.name.toLowerCase().contains(_search.toLowerCase()) ||
          p.pid.toString().contains(_search) ||
          p.user.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    list.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'cpu':
          cmp = a.cpu.compareTo(b.cpu);
          break;
        case 'mem':
          cmp = a.memory.compareTo(b.memory);
          break;
        case 'pid':
          cmp = a.pid.compareTo(b.pid);
          break;
        case 'name':
          cmp = a.name.compareTo(b.name);
          break;
        default:
          cmp = 0;
      }
      return _sortDesc ? -cmp : cmp;
    });

    _filtered = list;
  }

  void _setSort(String field) {
    setState(() {
      if (_sortBy == field) {
        _sortDesc = !_sortDesc;
      } else {
        _sortBy = field;
        _sortDesc = true;
      }
      _applyFilter();
    });
  }

  Future<void> _kill(ProcessInfo proc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('终止进程'),
        content: Text(
            '确定终止进程 ${proc.name} (PID: ${proc.pid})？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              child: const Text('终止')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _api.killProcess(proc.pid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已终止 ${proc.name}'),
            backgroundColor: AppTheme.success,
          ),
        );
        _refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('终止失败: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  void _showDetail(ProcessInfo proc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: AppTheme.border),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PID ${proc.pid}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    proc.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _detailRow('用户', proc.user),
            _detailRow('CPU', '${proc.cpu.toStringAsFixed(2)}%'),
            _detailRow('内存', '${proc.memory.toStringAsFixed(2)}%'),
            _detailRow('状态', proc.status),
            if (proc.cmdline.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('命令行',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  proc.cmdline,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textPrimary),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _kill(proc);
                },
                icon: const Icon(Icons.stop),
                label: const Text('终止进程'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                        _applyFilter();
                      });
                    },
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '搜索进程名、PID、用户...',
                      prefixIcon: const Icon(Icons.search,
                          color: AppTheme.textSecondary, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filtered.length}/${_all.length}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: _refresh,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          // Sort header
          Container(
            color: AppTheme.surfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                _sortHeader('PID', 'pid', 60),
                _sortHeader('名称', 'name', null),
                _sortHeader('CPU%', 'cpu', 52),
                _sortHeader('MEM%', 'mem', 52),
                const SizedBox(width: 32),
              ],
            ),
          ),
          // List
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
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(
                                    color: AppTheme.danger)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                                onPressed: _refresh,
                                child: const Text('重试')),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildRow(_filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sortHeader(String label, String field, double? width) {
    final active = _sortBy == field;
    Widget w() => GestureDetector(
          onTap: () => _setSort(field),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? AppTheme.primary : AppTheme.textSecondary,
                  fontWeight:
                      active ? FontWeight.w700 : FontWeight.normal,
                ),
              ),
              if (active)
                Icon(
                  _sortDesc ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 10,
                  color: AppTheme.primary,
                ),
            ],
          ),
        );

    if (width != null) {
      return SizedBox(width: width, child: w());
    }
    return Expanded(child: w());
  }

  Widget _buildRow(ProcessInfo proc) {
    final cpuColor = proc.cpu > 50
        ? AppTheme.danger
        : proc.cpu > 20
            ? AppTheme.warning
            : AppTheme.textPrimary;
    final memColor = proc.memory > 50
        ? AppTheme.danger
        : proc.memory > 20
            ? AppTheme.warning
            : AppTheme.textPrimary;

    return InkWell(
      onTap: () => _showDetail(proc),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(
                '${proc.pid}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    proc.name,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (proc.user.isNotEmpty)
                    Text(
                      proc.user,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 10),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${proc.cpu.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: cpuColor),
                textAlign: TextAlign.right,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${proc.memory.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: memColor),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _kill(proc),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Icon(Icons.stop_circle_outlined,
                    size: 20, color: AppTheme.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
