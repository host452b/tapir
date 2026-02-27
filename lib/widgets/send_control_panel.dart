import 'package:flutter/material.dart';
import '../models/key_step.dart';
import '../models/window_info.dart';
import '../services/key_sender_service.dart';
import '../theme/retro_theme.dart';

// =============================================================================
// segmented LED progress bar
//
// 20 pixel blocks fill left-to-right over each interval cycle.
// running: neonCyan segments + bright leading edge.
// paused:  frozen at last position, amber tint.
// idle:    all segments dark.
// =============================================================================

const int _kSegments = 20;

class _IntervalProgressBar extends StatefulWidget {
  final SendingState state;
  final int intervalMs;
  final int sendCount;

  const _IntervalProgressBar({
    required this.state,
    required this.intervalMs,
    required this.sendCount,
  });

  @override
  State<_IntervalProgressBar> createState() => _IntervalProgressBarState();
}

class _IntervalProgressBarState extends State<_IntervalProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// brief flash on each key fire
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.intervalMs),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(_IntervalProgressBar old) {
    super.didUpdateWidget(old);

    // detect a key fire: sendCount increased while running
    if (widget.state == SendingState.running &&
        widget.sendCount > old.sendCount) {
      _triggerFlash();
    }

    // interval changed -> update duration
    if (old.intervalMs != widget.intervalMs) {
      _controller.duration = Duration(milliseconds: widget.intervalMs);
    }

    // state changed -> start/stop animation
    if (old.state != widget.state) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.state == SendingState.running) {
      _controller.repeat();
    } else if (widget.state == SendingState.paused) {
      _controller.stop();
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  void _triggerFlash() {
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value; // 0.0 ~ 1.0
        final litCount = (progress * _kSegments).floor();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              // progress segments
              Row(
                children: List.generate(_kSegments, (i) {
                  final isLit = i < litCount;
                  final isEdge = i == litCount - 1 && widget.state == SendingState.running;

                  Color segColor;
                  if (widget.state == SendingState.idle) {
                    segColor = RC.bgDeep;
                  } else if (widget.state == SendingState.paused) {
                    segColor = isLit
                        ? RC.neonAmber.withValues(alpha: 0.5)
                        : RC.bgDeep;
                  } else if (_flash) {
                    segColor = RC.textBright;
                  } else if (isEdge) {
                    segColor = RC.neonCyan;
                  } else if (isLit) {
                    // gradient: earlier segments are dimmer
                    final intensity = 0.3 + 0.5 * (i / _kSegments);
                    segColor = RC.neonCyan.withValues(alpha: intensity);
                  } else {
                    segColor = RC.bgDeep;
                  }

                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 1),
                      decoration: BoxDecoration(
                        color: segColor,
                        border: Border.all(
                          color: isLit && widget.state != SendingState.idle
                              ? segColor.withValues(alpha: 0.6)
                              : RC.gridLine,
                          width: 1,
                        ),
                        boxShadow: isEdge
                            ? neonGlow(RC.neonCyan, intensity: 0.6, blur: 6)
                            : (_flash
                                ? neonGlow(RC.textBright, intensity: 0.8, blur: 10)
                                : null),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 3),

              // percentage + interval label
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.state == SendingState.idle
                        ? '---'
                        : '${(progress * 100).toInt()}%',
                    style: RText.micro.copyWith(
                      color: widget.state == SendingState.running
                          ? RC.neonCyan
                          : RC.textMuted,
                    ),
                  ),
                  Text(
                    'CYCLE ${widget.intervalMs}ms',
                    style: RText.micro.copyWith(color: RC.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// send control panel
// =============================================================================

/// send control panel: dominant state display, progress bar, action buttons,
/// compact readout.
class SendControlPanel extends StatelessWidget {
  final SendingState sendingState;
  final int sendCount;
  final WindowInfo? targetWindow;
  final int intervalMs;
  final List<KeyStep> steps;
  final VoidCallback? onStart;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final bool canStart;

  /// 0 = infinite loop, >0 = stop after N full cycles
  final int repeatCount;
  final int cyclesCompleted;
  final ValueChanged<int>? onRepeatCountChanged;

  const SendControlPanel({
    super.key,
    required this.sendingState,
    required this.sendCount,
    required this.targetWindow,
    required this.intervalMs,
    required this.steps,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.canStart,
    this.repeatCount = 0,
    this.cyclesCompleted = 0,
    this.onRepeatCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroBlock(),
        const SizedBox(height: 6),
        _buildReadout(),
      ],
    );
  }

  // ==========================================================================
  // hero block: state + counter + progress bar + buttons
  // ==========================================================================

  Widget _buildHeroBlock() {
    final stateColor = _stateColor();

    return Container(
      decoration: BoxDecoration(
        color: RC.bgMid,
        border: Border(
          top: BorderSide(color: stateColor, width: 2),
          left: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
        boxShadow: sendingState != SendingState.idle
            ? [
                BoxShadow(
                  color: stateColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: stateColor,
                        border: Border.all(color: stateColor, width: 1),
                        boxShadow: sendingState != SendingState.idle
                            ? neonGlow(stateColor, intensity: 0.7, blur: 10)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _stateLabel(),
                      style: RText.title.copyWith(
                        color: stateColor,
                        letterSpacing: 4.0,
                        shadows: sendingState != SendingState.idle
                            ? [Shadow(color: stateColor.withValues(alpha: 0.5), blurRadius: 8)]
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Text(
                  '$sendCount',
                  style: RText.display.copyWith(
                    color: sendingState == SendingState.running
                        ? RC.neonCyan
                        : RC.textDim,
                    shadows: sendingState == SendingState.running
                        ? [
                            Shadow(color: RC.neonCyan.withValues(alpha: 0.6), blurRadius: 12),
                            Shadow(color: RC.neonCyan.withValues(alpha: 0.3), blurRadius: 24),
                          ]
                        : null,
                  ),
                ),

                Text(
                  'EVENTS SENT',
                  style: RText.micro.copyWith(
                    color: RC.textMuted,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),

          // -- interval progress bar --
          _IntervalProgressBar(
            state: sendingState,
            intervalMs: intervalMs,
            sendCount: sendCount,
          ),

          // -- repeat mode strip --
          _RepeatModeStrip(
            repeatCount: repeatCount,
            cyclesCompleted: cyclesCompleted,
            sendingState: sendingState,
            onRepeatCountChanged: onRepeatCountChanged,
          ),

          // inline preflight warning
          if (!canStart && sendingState == SendingState.idle)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              color: RC.tintAmber,
              child: Row(
                children: [
                  Text(
                    '\u26A0',
                    style: RText.body.copyWith(color: RC.neonAmber),
                  ),
                  const SizedBox(width: 6),
                  if (targetWindow == null)
                    Text(
                      'Select a target window in TARGET tab',
                      style: RText.caption.copyWith(color: RC.neonAmber),
                    ),
                  if (targetWindow != null && steps.isEmpty)
                    Text(
                      'Add key steps in KEYS tab',
                      style: RText.caption.copyWith(color: RC.neonAmber),
                    ),
                ],
              ),
            ),

          // action buttons
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: RC.border, width: 1)),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildMainButton()),
                const SizedBox(width: 6),
                Expanded(
                  child: PixelButton(
                    label: 'PAUSE',
                    icon: Icons.pause,
                    color: RC.neonAmber,
                    filled: true,
                    onPressed: sendingState == SendingState.running
                        ? onPause
                        : null,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: PixelButton(
                    label: 'STOP',
                    icon: Icons.stop,
                    color: RC.neonMagenta,
                    filled: true,
                    onPressed: sendingState != SendingState.idle
                        ? onStop
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    if (sendingState == SendingState.paused) {
      return PixelButton(
        label: '\u25B6 RESUME',
        color: RC.neonGreen,
        filled: true,
        onPressed: onResume,
      );
    }
    return PixelButton(
      label: '\u25B6 START',
      color: RC.neonGreen,
      filled: true,
      onPressed: sendingState == SendingState.idle && canStart
          ? onStart
          : null,
    );
  }

  // ==========================================================================
  // readout grid
  // ==========================================================================

  Widget _buildReadout() {
    return PixelPanel(
      header: 'READOUT',
      accentColor: RC.neonGreen,
      padding: const EdgeInsets.all(6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _cell(
                  'TARGET',
                  targetWindow?.displayName ?? '---',
                  RC.neonCyan,
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 80,
                child: _cell(
                  'PID',
                  targetWindow != null ? '${targetWindow!.pid}' : '---',
                  RC.neonCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _cell(
            'SEQUENCE',
            steps.isNotEmpty
                ? steps.map((s) => s.displayName).join(' \u2192 ')
                : '---',
            RC.neonPurple,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _cell('INTERVAL', '${intervalMs}ms', RC.neonPurple),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _cell('STEPS', '${steps.length}', RC.neonPurple),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _cell('SENT', '$sendCount', RC.neonGreen),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _cell(
                  'REPEAT',
                  repeatCount == 0 ? '\u221E LOOP' : '$repeatCount CYCLES',
                  RC.neonAmber,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _cell(
                  'CYCLES',
                  repeatCount > 0
                      ? '$cyclesCompleted / $repeatCount'
                      : '$cyclesCompleted',
                  cyclesCompleted > 0 ? RC.neonAmber : RC.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const BoxDecoration(
        color: RC.bgDeep,
        border: Border(
          left: BorderSide(color: RC.gridLine, width: 1),
          right: BorderSide(color: RC.gridLine, width: 1),
          top: BorderSide(color: RC.gridLine, width: 1),
          bottom: BorderSide(color: RC.gridLine, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: RText.micro.copyWith(color: RC.textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: RText.body.copyWith(color: valueColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  String _stateLabel() {
    return switch (sendingState) {
      SendingState.idle => 'IDLE',
      SendingState.running => 'TRANSMITTING',
      SendingState.paused => 'PAUSED',
    };
  }

  Color _stateColor() {
    return switch (sendingState) {
      SendingState.idle => RC.textDim,
      SendingState.running => RC.neonGreen,
      SendingState.paused => RC.neonAmber,
    };
  }
}

// =============================================================================
// repeat mode strip - toggle between infinite and finite cycles
// =============================================================================

class _RepeatModeStrip extends StatefulWidget {
  final int repeatCount;
  final int cyclesCompleted;
  final SendingState sendingState;
  final ValueChanged<int>? onRepeatCountChanged;

  const _RepeatModeStrip({
    required this.repeatCount,
    required this.cyclesCompleted,
    required this.sendingState,
    this.onRepeatCountChanged,
  });

  @override
  State<_RepeatModeStrip> createState() => _RepeatModeStripState();
}

class _RepeatModeStripState extends State<_RepeatModeStrip> {
  late TextEditingController _countController;
  bool _inputError = false;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(
      text: widget.repeatCount > 0 ? widget.repeatCount.toString() : '',
    );
  }

  @override
  void didUpdateWidget(_RepeatModeStrip old) {
    super.didUpdateWidget(old);
    if (old.repeatCount != widget.repeatCount) {
      _countController.text =
          widget.repeatCount > 0 ? widget.repeatCount.toString() : '';
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  bool get _isEditable => widget.sendingState == SendingState.idle;
  bool get _isFinite => widget.repeatCount > 0;

  void _selectInfinite() {
    if (!_isEditable) return;
    widget.onRepeatCountChanged?.call(0);
  }

  void _selectFinite() {
    if (!_isEditable) return;
    if (!_isFinite) {
      widget.onRepeatCountChanged?.call(5);
    }
  }

  void _setCount(int n) {
    if (!_isEditable) return;
    widget.onRepeatCountChanged?.call(n);
  }

  Widget _segment(String label, bool active, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: _isEditable && !active ? onTap : null,
      child: MouseRegion(
        cursor: _isEditable && !active
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(
              color: active ? color.withValues(alpha: 0.6) : RC.border,
            ),
          ),
          child: Text(
            label,
            style: RText.micro.copyWith(
              color: active ? color : RC.textDim,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickPick(int n) {
    final active = widget.repeatCount == n;
    return GestureDetector(
      onTap: _isEditable ? () => _setCount(n) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: active ? RC.neonAmber.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(
            color: active ? RC.neonAmber.withValues(alpha: 0.5) : RC.gridLine,
          ),
        ),
        child: Text(
          '$n',
          style: RText.micro.copyWith(
            color: active ? RC.neonAmber : RC.textDim,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: RC.gridLine, width: 1),
        ),
      ),
      child: Column(
        children: [
          // row 1: segment selector + progress
          Row(
            children: [
              Text(
                'REPEAT',
                style: RText.micro.copyWith(
                  color: RC.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),

              _segment('\u221E LOOP', !_isFinite, RC.neonCyan, _selectInfinite),
              const SizedBox(width: 1),
              _segment('N\u00D7 REPEAT', _isFinite, RC.neonAmber, _selectFinite),

              const Spacer(),

              if (widget.sendingState != SendingState.idle &&
                  widget.repeatCount > 0)
                Text(
                  '${widget.cyclesCompleted}/${widget.repeatCount}',
                  style: RText.body.copyWith(
                    color: RC.neonAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),

          // row 2: quick picks + manual input (only when finite)
          if (_isFinite) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 58),
                _quickPick(1),
                const SizedBox(width: 2),
                _quickPick(3),
                const SizedBox(width: 2),
                _quickPick(5),
                const SizedBox(width: 2),
                _quickPick(10),
                const SizedBox(width: 2),
                _quickPick(50),
                const SizedBox(width: 2),
                _quickPick(100),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 20,
                  child: TextField(
                    controller: _countController,
                    enabled: _isEditable,
                    keyboardType: TextInputType.number,
                    style: RText.body.copyWith(color: RC.neonAmber, fontSize: 11),
                    cursorColor: RC.neonAmber,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      hintText: 'N',
                      hintStyle: RText.micro.copyWith(color: RC.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(
                          color: _inputError ? RC.neonMagenta : RC.border,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(
                          color: _inputError ? RC.neonMagenta : RC.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(
                          color: _inputError ? RC.neonMagenta : RC.neonAmber,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final n = int.tryParse(val);
                      if (n != null && n > 0 && n <= 999999) {
                        if (_inputError) setState(() => _inputError = false);
                        widget.onRepeatCountChanged?.call(n);
                      } else if (val.isNotEmpty) {
                        setState(() => _inputError = true);
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) setState(() => _inputError = false);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'cycles',
                  style: RText.micro.copyWith(color: RC.textDim),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
