import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../ai/ai_settings.dart';
import '../data/repository.dart';
import '../features/assistant/voice_capture.dart';
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

  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return TimelinePage(
      state: _state,
      filter: _filter,
      captureButton: VoiceCaptureButton(state: _state, ai: widget.ai),
      openOverview: () => _push(OverviewPage(state: _state, filter: _filter, openTimeline: () => Navigator.pop(context))),
      openSettings: () => _push(SettingsPage(state: _state, ai: widget.ai)),
    );
  }
}
