import 'package:flutter/material.dart';
import '../models/key_step.dart';
import '../models/window_info.dart';
import '../services/key_sender_service.dart';
import '../services/native_bridge.dart';
import '../theme/retro_theme.dart';
import '../widgets/event_log.dart';
import '../widgets/key_config_panel.dart';
import '../widgets/permission_banner.dart';
import '../widgets/send_control_panel.dart';
import '../widgets/window_selector.dart';

// =============================================================================
// sidebar tab enum
// =============================================================================

enum SidebarTab { target, keys, control, system }

// =============================================================================
// home page - sidebar + content + status bar
// =============================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // navigation
  SidebarTab _activeTab = SidebarTab.target;

  // window selection
  WindowInfo? _selectedWindow;

  // key configuration
  final List<KeyStep> _keySteps = [];
  int _intervalMs = 500;

  // sending service
  final KeySenderService _senderService = KeySenderService();
  SendingState _sendingState = SendingState.idle;
  int _sendCount = 0;
  int _repeatCount = 0;
  int _cyclesCompleted = 0;

  // permission
  bool _hasPermission = false;

  // event log
  final List<LogEntry> _logEntries = [];

  // error throttle: prevent SnackBar spam during continuous send failures
  DateTime? _lastErrorShownAt;

  @override
  void initState() {
    super.initState();
    _setupServiceCallbacks();
    _checkPermission();
  }

  @override
  void dispose() {
    _senderService.dispose();
    super.dispose();
  }

  void _setupServiceCallbacks() {
    _senderService.onSendCountChanged = (count) {
      setState(() => _sendCount = count);
    };
    _senderService.onStateChanged = (state) {
      setState(() => _sendingState = state);
    };
    _senderService.onError = (error) {
      // throttle: show at most one error per 3 seconds to avoid SnackBar spam
      // when the target process continuously refuses events
      final now = DateTime.now();
      if (_lastErrorShownAt != null &&
          now.difference(_lastErrorShownAt!).inSeconds < 3) {
        return;
      }
      _lastErrorShownAt = now;
      _showMessage(error, isError: true);
    };
    _senderService.onWindowInvalid = () {
      _showMessage('TARGET LOST - window no longer visible', isError: true);
    };
    _senderService.onCycleCompleted = (cycles) {
      setState(() => _cyclesCompleted = cycles);
    };
    _senderService.onLog = (type, message) {
      _addLogEntry(type, message);
    };
  }

  void _addLogEntry(String type, String message) {
    setState(() {
      _logEntries.add(LogEntry(
        timestamp: DateTime.now(),
        type: type,
        message: message,
      ));
      // cap to prevent unbounded memory growth
      if (_logEntries.length > kMaxLogEntries) {
        _logEntries.removeRange(0, _logEntries.length - kMaxLogEntries);
      }
    });
  }

  void _clearLog() {
    setState(() => _logEntries.clear());
  }

  Future<void> _checkPermission() async {
    final granted = await NativeBridge.checkAccessibility();
    if (!mounted) return;
    setState(() => _hasPermission = granted);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: RText.body.copyWith(color: RC.textBright),
        ),
        backgroundColor: isError ? RC.tintMagenta : RC.bgPanel,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool get _canStart => _selectedWindow != null && _keySteps.isNotEmpty;
  bool get _isEditable => _sendingState == SendingState.idle;

  // -- actions --
  void _onWindowSelected(WindowInfo? w) => setState(() => _selectedWindow = w);

  void _addKeyStep() {
    setState(() => _keySteps.add(KeyStep(keyName: 'Return')));
  }

  void _removeKeyStep(int i) {
    if (i >= 0 && i < _keySteps.length) {
      setState(() => _keySteps.removeAt(i));
    }
  }

  void _duplicateKeyStep(int i) {
    if (i >= 0 && i < _keySteps.length) {
      setState(() => _keySteps.insert(i + 1, _keySteps[i].copy()));
    }
  }

  void _moveKeyStep(int from, int to) {
    if (from < 0 || from >= _keySteps.length) return;
    if (to < 0 || to >= _keySteps.length) return;
    if (from == to) return;
    setState(() {
      final step = _keySteps.removeAt(from);
      _keySteps.insert(to, step);
    });
  }

  void _onStepsChanged() => setState(() {});
  void _onIntervalChanged(int ms) => setState(() => _intervalMs = ms);
  void _onRepeatCountChanged(int count) =>
      setState(() => _repeatCount = count);

  void _startSending() {
    if (_selectedWindow == null) {
      _showMessage('ERR: select a target window first', isError: true);
      return;
    }
    if (_keySteps.isEmpty) {
      _showMessage('ERR: add at least one key step', isError: true);
      return;
    }
    setState(() => _cyclesCompleted = 0);
    _senderService.start(
      targetWindow: _selectedWindow!,
      steps: _keySteps,
      intervalMs: _intervalMs,
      repeatCount: _repeatCount,
    );
  }

  void _pauseSending() => _senderService.pause();
  void _resumeSending() => _senderService.resume();

  void _stopSending() {
    _senderService.stop();
    setState(() {
      _sendCount = 0;
      _cyclesCompleted = 0;
    });
  }

  // ==========================================================================
  // build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RC.bgDark,
      body: Column(
        children: [
          _buildTitleBar(),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Container(width: 1, color: RC.border),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
          _buildStatusBar(),
        ],
      ),
    );
  }

  // ==========================================================================
  // title bar (compact, 32px)
  // ==========================================================================

  Widget _buildTitleBar() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [RC.bgDeep, Color(0xFF0A0A22)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: const Border(bottom: BorderSide(color: RC.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: RC.neonCyan.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: RC.neonCyan,
              border: Border.all(color: RC.neonCyan, width: 1),
              boxShadow: neonGlow(RC.neonCyan, intensity: 0.6, blur: 8),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'TAPIR',
            style: RText.caption.copyWith(
              color: RC.neonCyan,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: RC.neonCyan.withValues(alpha: 0.5),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'KEY SENDER',
            style: RText.caption.copyWith(
              color: RC.textDim,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          // inline context badge: constrain width so long app names
          // don't push version label off screen
          if (_selectedWindow != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: PixelBadge(
                text: '${_selectedWindow!.ownerName}:${_selectedWindow!.pid}',
                color: RC.neonCyan,
              ),
            ),
          if (_keySteps.isNotEmpty) ...[
            const SizedBox(width: 4),
            PixelBadge(
              text: '${_keySteps.length} KEYS',
              color: RC.neonPurple,
            ),
          ],
          const SizedBox(width: 8),
          Text('v1.0', style: RText.micro.copyWith(color: RC.textMuted)),
        ],
      ),
    );
  }

  // ==========================================================================
  // sidebar (120px, tighter items)
  // ==========================================================================

  Widget _buildSidebar() {
    return Container(
      width: 120,
      color: RC.bgDeep,
      child: Column(
        children: [
          const SizedBox(height: 6),
          _sidebarItem(
            tab: SidebarTab.target,
            label: 'TARGET',
            accent: RC.neonCyan,
            badge: _selectedWindow != null ? '\u2713' : null,
            badgeColor: RC.neonGreen,
          ),
          _sidebarItem(
            tab: SidebarTab.keys,
            label: 'KEYS',
            accent: RC.neonPurple,
            badge: _keySteps.isNotEmpty ? '${_keySteps.length}' : null,
            badgeColor: RC.neonPurple,
          ),
          _sidebarItem(
            tab: SidebarTab.control,
            label: 'CONTROL',
            accent: RC.neonGreen,
            badge: _sendingState != SendingState.idle ? '\u25CF' : null,
            badgeColor: _sendingState == SendingState.running
                ? RC.neonGreen
                : RC.neonAmber,
          ),
          _sidebarItem(
            tab: SidebarTab.system,
            label: 'SYSTEM',
            accent: RC.neonAmber,
            badge: !_hasPermission ? '!' : null,
            badgeColor: RC.neonMagenta,
          ),
          const SizedBox(height: 8),
          // sequence mini preview: inside Expanded so it scrolls
          // instead of overflowing the Column when many steps exist
          Expanded(
            child: _keySteps.isNotEmpty
                ? SingleChildScrollView(
                    child: _sidebarSequencePreview(),
                  )
                : const SizedBox.shrink(),
          ),
          _sidebarStateIndicator(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _sidebarItem({
    required SidebarTab tab,
    required String label,
    required Color accent,
    String? badge,
    Color badgeColor = RC.textDim,
  }) {
    final active = _activeTab == tab;

    return _HoverBuilder(
      builder: (hovering) {
        return GestureDetector(
          onTap: () => setState(() => _activeTab = tab),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: 0.10)
                  : (hovering ? accent.withValues(alpha: 0.04) : Colors.transparent),
              border: Border(
                left: BorderSide(
                  color: active ? accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: active ? accent : Colors.transparent,
                    boxShadow: active
                        ? neonGlow(accent, intensity: 0.6, blur: 6)
                        : null,
                  ),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: RText.caption.copyWith(
                      color: active
                          ? accent
                          : (hovering ? RC.textSecond : RC.textDim),
                      fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                      letterSpacing: 1.5,
                      shadows: active
                          ? [Shadow(color: accent.withValues(alpha: 0.4), blurRadius: 4)]
                          : null,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    constraints: const BoxConstraints(minWidth: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.5),
                      ),
                      boxShadow: neonGlow(badgeColor, intensity: 0.2, blur: 4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badge,
                      style: RText.micro.copyWith(
                        color: badgeColor,
                        fontSize: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sidebarSequencePreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(5),
        decoration: const BoxDecoration(
          color: RC.bgDark,
          border: Border(
            top: BorderSide(color: RC.gridLine, width: 1),
            bottom: BorderSide(color: RC.gridLine, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // label (micro - 9px, very subtle)
            Text(
              'SEQUENCE',
              style: RText.micro.copyWith(
                color: RC.textMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (int i = 0; i < _keySteps.length; i++) ...[
                  if (i > 0)
                    Text(
                      '\u203A',
                      style: TextStyle(
                        fontFamily: kFontMono,
                        fontSize: 8,
                        color: RC.textMuted,
                      ),
                    ),
                  PixelBadge(
                    text: _keySteps[i].displayName,
                    color: switch (_keySteps[i].mode) {
                      StepMode.key => RC.neonPurple,
                      StepMode.text => RC.neonGreen,
                      StepMode.combo => RC.neonAmber,
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            // interval value (body tier - stands out from micro label)
            Text(
              '${_intervalMs}ms',
              style: RText.body.copyWith(
                color: RC.neonPurple,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarStateIndicator() {
    Color dotColor;
    String label;
    switch (_sendingState) {
      case SendingState.idle:
        dotColor = RC.textDim;
        label = 'IDLE';
      case SendingState.running:
        dotColor = RC.neonGreen;
        label = 'ACTIVE';
      case SendingState.paused:
        dotColor = RC.neonAmber;
        label = 'PAUSED';
    }

    final isActive = _sendingState != SendingState.idle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dotColor,
              border: Border.all(color: dotColor, width: 1),
              boxShadow: isActive
                  ? neonGlow(dotColor, intensity: 0.7, blur: 8)
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: RText.micro.copyWith(
              color: dotColor,
              shadows: isActive
                  ? [Shadow(color: dotColor.withValues(alpha: 0.5), blurRadius: 4)]
                  : null,
            ),
          ),
          if (_sendingState == SendingState.running) ...[
            const Spacer(),
            // count value (body tier - jumps out from micro label)
            Text(
              '$_sendCount',
              style: RText.body.copyWith(
                color: RC.neonGreen,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // content area
  // ==========================================================================

  Widget _buildContent() {
    return Container(
      color: RC.bgDark,
      child: switch (_activeTab) {
        SidebarTab.target => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Expanded(
                  child: WindowSelector(
                    selectedWindow: _selectedWindow,
                    onWindowSelected: _onWindowSelected,
                    enabled: _isEditable,
                  ),
                ),
                if (_selectedWindow != null && _keySteps.isEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _activeTab = SidebarTab.keys),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: RC.neonGreen.withValues(alpha: 0.06),
                        border: Border.all(
                          color: RC.neonGreen.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '\u2192',
                            style: TextStyle(
                              fontFamily: kFontMono,
                              fontSize: 12,
                              color: RC.neonGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TARGET SET \u2014 configure key steps in KEYS tab',
                            style: RText.caption.copyWith(
                              color: RC.neonGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        SidebarTab.keys => SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: KeyConfigPanel(
              steps: _keySteps,
              intervalMs: _intervalMs,
              onIntervalChanged: _onIntervalChanged,
              onAddStep: _addKeyStep,
              onRemoveStep: _removeKeyStep,
              onMoveStep: _moveKeyStep,
              onDuplicateStep: _duplicateKeyStep,
              onStepsChanged: _onStepsChanged,
              enabled: _isEditable,
            ),
          ),
        SidebarTab.control => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // control panel (fixed height at top)
                SendControlPanel(
                  sendingState: _sendingState,
                  sendCount: _sendCount,
                  targetWindow: _selectedWindow,
                  intervalMs: _intervalMs,
                  steps: _keySteps,
                  onStart: _startSending,
                  onPause: _pauseSending,
                  onResume: _resumeSending,
                  onStop: _stopSending,
                  canStart: _canStart,
                  repeatCount: _repeatCount,
                  cyclesCompleted: _cyclesCompleted,
                  onRepeatCountChanged: _isEditable
                      ? _onRepeatCountChanged
                      : null,
                ),
                const SizedBox(height: 6),
                // event log (fills remaining space)
                Expanded(
                  child: EventLog(
                    entries: _logEntries,
                    onClear: _clearLog,
                  ),
                ),
              ],
            ),
          ),
        SidebarTab.system => SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: PermissionBanner(
              onPermissionChanged: () => _checkPermission(),
            ),
          ),
      },
    );
  }

  // ==========================================================================
  // status bar (24px, tighter)
  // ==========================================================================

  Widget _buildStatusBar() {
    final targetLabel = _selectedWindow != null
        ? '${_selectedWindow!.ownerName}:${_selectedWindow!.pid}'
        : '---';

    return Container(
      height: 24,
      decoration: const BoxDecoration(
        color: RC.bgDeep,
        border: Border(top: BorderSide(color: RC.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _hasPermission ? RC.neonGreen : RC.neonMagenta,
              border: Border.all(
                color: _hasPermission ? RC.neonGreen : RC.neonMagenta,
                width: 1,
              ),
              boxShadow: neonGlow(
                _hasPermission ? RC.neonGreen : RC.neonMagenta,
                intensity: 0.6,
                blur: 6,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            _hasPermission ? 'OK' : '!!',
            style: RText.micro.copyWith(
              color: _hasPermission ? RC.neonGreen : RC.neonMagenta,
            ),
          ),
          _sep(),
          // flexible so long window names truncate instead of pushing
          // SENT/interval/state off the right edge
          Flexible(
            child: Text(
              'TGT $targetLabel',
              style: RText.status,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          _sep(),
          // send count (slightly emphasized)
          Text('SENT ', style: RText.status),
          Text(
            '$_sendCount',
            style: RText.status.copyWith(
              color: _sendCount > 0 ? RC.neonCyan : RC.textDim,
              fontWeight: FontWeight.w700,
            ),
          ),
          _sep(),
          Text('${_intervalMs}ms', style: RText.status),
          const Spacer(),
          Text(
            _sendingState.name.toUpperCase(),
            style: RText.status.copyWith(
              color: switch (_sendingState) {
                SendingState.idle => RC.textDim,
                SendingState.running => RC.neonGreen,
                SendingState.paused => RC.neonAmber,
              },
              fontWeight: FontWeight.w700,
              shadows: _sendingState != SendingState.idle
                  ? [
                      Shadow(
                        color: (_sendingState == SendingState.running
                                ? RC.neonGreen
                                : RC.neonAmber)
                            .withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '\u2502',
        style: TextStyle(fontFamily: kFontMono, fontSize: 10, color: RC.border),
      ),
    );
  }
}

// =============================================================================
// lightweight hover detector that avoids per-widget StatefulWidget boilerplate
// =============================================================================

class _HoverBuilder extends StatefulWidget {
  final Widget Function(bool hovering) builder;
  const _HoverBuilder({required this.builder});

  @override
  State<_HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<_HoverBuilder> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: widget.builder(_hovering),
    );
  }
}
