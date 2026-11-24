import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/ai_settings.dart';
import '../data/repository.dart';
import '../features/assistant/assistant_page.dart';
import '../features/metrics/metrics_page.dart';
import '../features/overview/overview_page.dart';
import '../features/settings/settings_page.dart';
import '../features/timeline/timeline_filter.dart';
import '../features/timeline/timeline_page.dart';
import '../state/app_state.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.client, required this.ai});
  final SupabaseClient client;
  final AiSettings ai;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _filter = TimelineFilter();
  late final AppState _state = AppState(Repository(widget.client));
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _state.load();
  }

  @override
  void dispose() {
    _filter.dispose();
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      TimelinePage(state: _state, filter: _filter),
      OverviewPage(state: _state, filter: _filter, openTimeline: () => setState(() => _tab = 0)),
      AssistantPage(state: _state, ai: widget.ai),
      MetricsPage(state: _state),
      SettingsPage(state: _state, ai: widget.ai),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_timeline_outlined), selectedIcon: Icon(Icons.view_timeline), label: 'Timeline'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'ภาพรวม'),
          NavigationDestination(icon: _CaptureIcon(), selectedIcon: _CaptureIcon(selected: true), label: 'บันทึก'),
          NavigationDestination(icon: Icon(Icons.show_chart), label: 'ตัวเลข'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'ตั้งค่า'),
        ],
      ),
    );
  }
}

/// ปุ่มกลางของแถบล่าง: จุดเริ่มบันทึกด้วย AI เด่นกว่าแท็บอื่น
class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon({this.selected = false});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.onSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.auto_awesome, size: 18, color: scheme.surface),
    );
  }
}
