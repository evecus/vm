import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class DashboardScreen extends StatefulWidget {
  final ServerConfig server;
  const DashboardScreen({super.key, required this.server});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late ApiService _api;
  SystemInfo? _info;
  bool _loading = true;
  String? _error;
  Timer? _timer;

  final List<double> _cpuHistory = List.filled(30, 0, growable: true);
  final List<double> _memHistory = List.filled(30, 0, growable: true);

  @override
  void initState() {
    super.initState();
    _api = ApiService(widget.server);
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final info = await _api.getSystemInfo();
      if (mounted) {
        setState(() {
          _info = info;
          _loading = false;
          _error = null;
          _cpuHistory.removeAt(0);
          _cpuHistory.add(info.cpu.avgPercent);
          _memHistory.removeAt(0);
          _memHistory.add(info.memory.percent);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _refresh, child: const Text('重试')),
          ],
        ),
      );
    }

    final info = _info!;
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Host info
          _hostCard(info),
          const SizedBox(height: 12),
          // CPU
          _chartCard(
            title: 'CPU',
            value: '${info.cpu.avgPercent.toStringAsFixed(1)}%',
            subtitle: info.cpu.model,
            history: _cpuHistory,
            color: AppTheme.primary,
            icon: Icons.memory,
          ),
          const SizedBox(height: 12),
          // Memory
          _chartCard(
            title: '内存',
            value: '${info.memory.percent.toStringAsFixed(1)}%',
            subtitle:
                '${formatBytes(info.memory.used)} / ${formatBytes(info.memory.total)}',
            history: _memHistory,
            color: AppTheme.info,
            icon: Icons.storage,
          ),
          const SizedBox(height: 12),
          // Disk + Load row
          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: '磁盘',
                  value: '${info.disk.percent.toStringAsFixed(1)}%',
                  sub: '${formatBytes(info.disk.used)} / ${formatBytes(info.disk.total)}',
                  icon: Icons.disc_full,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: '负载',
                  value: info.load.load1.toStringAsFixed(2),
                  sub: '5m: ${info.load.load5.toStringAsFixed(2)}  15m: ${info.load.load15.toStringAsFixed(2)}',
                  icon: Icons.show_chart,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Network
          _networkCard(info),
        ],
      ),
    );
  }

  Widget _hostCard(SystemInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.computer, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                info.host.hostname,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('系统', '${info.host.platform} ${info.host.platformVersion}'),
          _infoRow('内核', info.host.kernelVersion),
          _infoRow('运行时间', formatUptime(info.host.uptime)),
          _infoRow('CPU 核心', '${info.cpu.cores} 核'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _chartCard({
    required String title,
    required String value,
    required String subtitle,
    required List<double> history,
    required Color color,
    required IconData icon,
  }) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ],
                lineTouchData: const LineTouchData(enabled: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(sub,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _networkCard(SystemInfo info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.network_check, color: AppTheme.success, size: 18),
              SizedBox(width: 8),
              Text('网络',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _netStat(
                  '上传',
                  formatBytes(info.network.bytesSent),
                  Icons.arrow_upward,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _netStat(
                  '下载',
                  formatBytes(info.network.bytesRecv),
                  Icons.arrow_downward,
                  AppTheme.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _netStat(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11)),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
