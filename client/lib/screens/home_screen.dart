import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'file_manager_screen.dart';
import 'terminal_screen.dart';
import 'process_screen.dart';
import 'services_screen.dart';

class HomeScreen extends StatefulWidget {
  final ServerConfig server;
  const HomeScreen({super.key, required this.server});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  static const _navItems = [
    _NavItem(Icons.dashboard_outlined, Icons.dashboard, '仪表盘'),
    _NavItem(Icons.folder_outlined, Icons.folder, '文件'),
    _NavItem(Icons.terminal_outlined, Icons.terminal, '终端'),
    _NavItem(Icons.memory_outlined, Icons.memory, '进程'),
    _NavItem(Icons.settings_applications_outlined,
        Icons.settings_applications, '服务'),
  ];

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(server: widget.server),
      FileManagerScreen(server: widget.server),
      TerminalScreen(server: widget.server),
      ProcessScreen(server: widget.server),
      ServicesScreen(server: widget.server),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.server.name),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _ScrollableNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ── Scrollable bottom nav bar ─────────────────────────────────────
class _ScrollableNavBar extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;

  const _ScrollableNavBar({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56 + bottomPad,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(bottom: bottomPad),
            // Make each item take equal share but at minimum 72px so it's
            // scrollable when there are many tabs.
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                // Use screen width divided by items, with min 72
                final screenW = MediaQuery.of(context).size.width;
                final itemW =
                    (screenW / items.length).clamp(72.0, 100.0);
                return Row(
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    final active = i == currentIndex;
                    return GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: itemW,
                        height: 56,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                active ? item.activeIcon : item.icon,
                                color: active
                                    ? AppTheme.primary
                                    : AppTheme.textSecondary,
                                size: 22,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: active
                                      ? AppTheme.primary
                                      : AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              // active indicator dot
                              const SizedBox(height: 2),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: active ? 16 : 0,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
