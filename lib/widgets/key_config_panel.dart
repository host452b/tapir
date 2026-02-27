import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/key_codes.dart';
import '../models/key_step.dart';
import '../theme/retro_theme.dart';

/// key configuration panel: sequence preview, interval, and key step cards.
/// information density:
///   - sequence preview is compact (micro labels + body badges)
///   - interval inlined with button labels as caption
///   - each card: title-level step number, body key, caption modifiers
class KeyConfigPanel extends StatelessWidget {
  final List<KeyStep> steps;
  final int intervalMs;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback onAddStep;
  final void Function(int index) onRemoveStep;
  final void Function(int from, int to) onMoveStep;
  final void Function(int index) onDuplicateStep;
  final VoidCallback onStepsChanged;
  final bool enabled;

  const KeyConfigPanel({
    super.key,
    required this.steps,
    required this.intervalMs,
    required this.onIntervalChanged,
    required this.onAddStep,
    required this.onRemoveStep,
    required this.onMoveStep,
    required this.onDuplicateStep,
    required this.onStepsChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- sequence preview (compact strip) --
        if (steps.isNotEmpty) ...[
          _SequencePreview(steps: steps, intervalMs: intervalMs),
          const SizedBox(height: 6),
        ],

        // -- interval (compact) --
        _IntervalStrip(
          intervalMs: intervalMs,
          onChanged: enabled ? onIntervalChanged : null,
        ),
        const SizedBox(height: 6),

        // -- key steps list (drag-to-reorder) --
        PixelPanel(
          header: 'STEPS  (${steps.length})',
          accentColor: RC.neonPurple,
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              if (steps.isEmpty)
                _emptyState()
              else
                // wrap in a constrained box so ReorderableListView
                // gets a bounded height based on actual item count
                ConstrainedBox(
                  constraints: BoxConstraints(
                    // estimate ~70px per card; scrollable inside panel
                    maxHeight: steps.length * 82.0 + 8,
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    proxyDecorator: _proxyDecorator,
                    itemCount: steps.length,
                    onReorder: (oldIndex, newIndex) {
                      // ReorderableListView passes newIndex *before* removal,
                      // so adjust when moving downward
                      if (newIndex > oldIndex) newIndex--;
                      onMoveStep(oldIndex, newIndex);
                    },
                    itemBuilder: (context, i) {
                      return Padding(
                        key: ValueKey(steps[i].hashCode ^ i),
                        padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                        child: _KeyStepCard(
                          index: i,
                          total: steps.length,
                          step: steps[i],
                          enabled: enabled,
                          onChanged: onStepsChanged,
                          onRemove: () => onRemoveStep(i),
                          onDuplicate: () => onDuplicateStep(i),
                          onMoveUp: i > 0
                              ? () => onMoveStep(i, i - 1)
                              : null,
                          onMoveDown: i < steps.length - 1
                              ? () => onMoveStep(i, i + 1)
                              : null,
                          dragIndex: i,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 6),
              // add buttons
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      label: 'KEY',
                      icon: Icons.keyboard,
                      color: RC.neonPurple,
                      compact: true,
                      onPressed: enabled ? onAddStep : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: PixelButton(
                      label: 'TEXT',
                      icon: Icons.text_fields,
                      color: RC.neonGreen,
                      compact: true,
                      onPressed: enabled
                          ? () {
                              steps.add(KeyStep(mode: StepMode.text));
                              onStepsChanged();
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: PixelButton(
                      label: 'COMBO',
                      icon: Icons.playlist_play,
                      color: RC.neonAmber,
                      compact: true,
                      onPressed: enabled
                          ? () {
                              steps.add(KeyStep(mode: StepMode.combo));
                              onStepsChanged();
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // mode descriptions
              _modeDescriptions(),
            ],
          ),
        ),
      ],
    );
  }

  /// visual decorator for the item being dragged
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: RC.neonPurple, width: 1),
              boxShadow: [
                BoxShadow(
                  color: RC.neonPurple.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// mode descriptions shown below the add buttons
  Widget _modeDescriptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: RC.bgDeep,
        border: Border.all(color: RC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _modeHint(
            'KEY',
            RC.neonPurple,
            'single key or shortcut (e.g. Cmd+C)',
          ),
          const SizedBox(height: 3),
          _modeHint(
            'TXT',
            RC.neonGreen,
            'type a text string, optionally press Enter',
          ),
          const SizedBox(height: 3),
          _modeHint(
            'CMB',
            RC.neonAmber,
            'key \u2192 text \u2192 key  (e.g. Tab \u2192 "hello" \u2192 Enter)',
          ),
        ],
      ),
    );
  }

  Widget _modeHint(String tag, Color color, String desc) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.5)),
            color: color.withValues(alpha: 0.08),
          ),
          child: Text(
            tag,
            style: RText.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            desc,
            style: RText.micro.copyWith(color: RC.textDim),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: RC.bgDeep,
      child: Column(
        children: [
          Text(
            '\u2328',
            style: TextStyle(fontSize: 24, color: RC.textDim),
          ),
          const SizedBox(height: 8),
          Text(
            'NO STEPS CONFIGURED',
            style: RText.caption.copyWith(
              color: RC.textSecond,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'add a step using the buttons below',
            style: RText.body.copyWith(
              color: RC.textDim,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PixelBadge(text: 'KEY', color: RC.neonPurple),
              const SizedBox(width: 4),
              Text(
                'single key',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
              const SizedBox(width: 8),
              PixelBadge(text: 'TEXT', color: RC.neonGreen),
              const SizedBox(width: 4),
              Text(
                'type string',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
              const SizedBox(width: 8),
              PixelBadge(text: 'COMBO', color: RC.neonAmber),
              const SizedBox(width: 4),
              Text(
                'key+text+key',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// sequence preview strip - body badges + micro labels
// =============================================================================

class _SequencePreview extends StatelessWidget {
  final List<KeyStep> steps;
  final int intervalMs;

  const _SequencePreview({required this.steps, required this.intervalMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const BoxDecoration(
        color: RC.bgDeep,
        border: Border(
          top: BorderSide(color: RC.neonPurple, width: 1),
          left: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'FLOW',
            style: RText.micro.copyWith(color: RC.textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < steps.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          '\u2192',
                          style: TextStyle(
                            fontFamily: kFontMono,
                            fontSize: 11,
                            color: RC.textMuted,
                          ),
                        ),
                      ),
                    PixelBadge(
                      text: steps[i].displayName,
                      color: _modeColor(steps[i].mode),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // interval as accent value next to flow
          Text(
            '${intervalMs}ms',
            style: RText.body.copyWith(
              color: RC.neonPurple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// interval strip - compact, no separate PixelPanel wrapper
// =============================================================================

class _IntervalStrip extends StatefulWidget {
  final int intervalMs;
  final ValueChanged<int>? onChanged;

  const _IntervalStrip({required this.intervalMs, this.onChanged});

  @override
  State<_IntervalStrip> createState() => _IntervalStripState();
}

class _IntervalStripState extends State<_IntervalStrip> {
  late final TextEditingController _controller;
  bool _isUserEditing = false;
  bool _inputError = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.intervalMs.toString());
  }

  @override
  void didUpdateWidget(_IntervalStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // sync text field when value changes externally (via buttons)
    // but only if the user is not actively typing
    if (oldWidget.intervalMs != widget.intervalMs && !_isUserEditing) {
      _controller.text = widget.intervalMs.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _adjust(int delta) {
    final next = (widget.intervalMs + delta).clamp(100, 10000000);
    widget.onChanged?.call(next);
  }

  /// helper to build a compact step button
  Widget _stepBtn(String label, int delta) {
    return PixelButton(
      label: label,
      color: RC.neonPurple,
      compact: true,
      onPressed: widget.onChanged != null ? () => _adjust(delta) : null,
    );
  }

  /// format large values for display (e.g. 1500000 -> "1,500,000")
  String _formatMs(int ms) {
    final s = ms.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: RC.bgMid,
        border: Border(
          top: BorderSide(color: RC.neonPurple, width: 1),
          left: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // row 1: label + step buttons + value display
          Row(
            children: [
              Text(
                'INTERVAL',
                style: RText.micro.copyWith(
                  color: RC.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              _stepBtn('-10k', -10000),
              const SizedBox(width: 2),
              _stepBtn('-1k', -1000),
              const SizedBox(width: 2),
              _stepBtn('-100', -100),
              const SizedBox(width: 2),
              _stepBtn('-10', -10),
              const SizedBox(width: 6),

              // prominent value display (wider for large numbers)
              Expanded(
                child: Container(
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RC.bgDeep,
                    border: Border.all(color: RC.neonPurple, width: 1),
                  ),
                  child: Text(
                    '${_formatMs(widget.intervalMs)}ms',
                    style: RText.body.copyWith(
                      color: RC.neonPurple,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              _stepBtn('+10', 10),
              const SizedBox(width: 2),
              _stepBtn('+100', 100),
              const SizedBox(width: 2),
              _stepBtn('+1k', 1000),
              const SizedBox(width: 2),
              _stepBtn('+10k', 10000),
            ],
          ),
          const SizedBox(height: 4),

          // row 2: direct input + range hint
          Row(
            children: [
              Text(
                'DIRECT',
                style: RText.micro.copyWith(
                  color: RC.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    _isUserEditing = hasFocus;
                    if (!hasFocus) {
                      _controller.text = widget.intervalMs.toString();
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: RText.body.copyWith(color: RC.neonPurple),
                    cursorColor: RC.neonPurple,
                    decoration: InputDecoration(
                      suffixText: 'ms',
                      suffixStyle: RText.micro.copyWith(color: RC.textDim),
                      filled: true,
                      fillColor: RC.bgDeep,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 5,
                      ),
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
                          color: _inputError ? RC.neonMagenta : RC.neonPurple,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final ms = int.tryParse(val);
                      if (ms != null && ms >= 100 && ms <= 10000000) {
                        if (_inputError) setState(() => _inputError = false);
                        widget.onChanged?.call(ms);
                      } else if (val.isNotEmpty) {
                        setState(() => _inputError = true);
                        Future.delayed(const Duration(milliseconds: 600), () {
                          if (mounted) setState(() => _inputError = false);
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '100ms \u2013 10,000,000ms',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// key step card - supports key / text / combo modes
// =============================================================================

/// accent color for each step mode
Color _modeColor(StepMode m) {
  switch (m) {
    case StepMode.key:
      return RC.neonCyan;
    case StepMode.text:
      return RC.neonGreen;
    case StepMode.combo:
      return RC.neonAmber;
  }
}

class _KeyStepCard extends StatefulWidget {
  final int index;
  final int total;
  final KeyStep step;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final int dragIndex; // for ReorderableDragStartListener

  const _KeyStepCard({
    required this.index,
    required this.total,
    required this.step,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
    required this.onDuplicate,
    this.onMoveUp,
    this.onMoveDown,
    required this.dragIndex,
  });

  @override
  State<_KeyStepCard> createState() => _KeyStepCardState();
}

class _KeyStepCardState extends State<_KeyStepCard> {
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.step.textContent);
  }

  @override
  void didUpdateWidget(covariant _KeyStepCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step &&
        _textCtrl.text != widget.step.textContent) {
      _textCtrl.text = widget.step.textContent;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final accent = _modeColor(step.mode);

    return Container(
      decoration: BoxDecoration(
        color: RC.bgPanel,
        border: Border(
          left: BorderSide(color: accent, width: 3),
          top: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(step, accent),
          switch (step.mode) {
            StepMode.key => _buildKeyBody(step),
            StepMode.text => _buildTextBody(step),
            StepMode.combo => _buildComboBody(step),
          },
        ],
      ),
    );
  }

  // ---------- header row ----------

  Widget _buildHeader(KeyStep step, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: RC.bgDeep,
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.5)),
              boxShadow: neonGlow(accent, intensity: 0.2, blur: 4),
            ),
            child: Text(
              '${widget.index + 1}',
              style: RText.body.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),

          // mode toggle (cycles: key → text → combo → key)
          _modeToggle(step.mode),
          const SizedBox(width: 5),

          const Spacer(),

          // result badge
          Flexible(
            flex: 0,
            child: PixelBadge(text: step.displayName, color: accent),
          ),
          const SizedBox(width: 6),

          Tooltip(
            message: 'drag to reorder',
            child: ReorderableDragStartListener(
              index: widget.dragIndex,
              enabled: widget.enabled,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.enabled
                        ? accent.withValues(alpha: 0.4)
                        : RC.gridLine,
                  ),
                ),
                child: Text(
                  '\u2261',
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 14,
                    color: widget.enabled ? accent : RC.textMuted,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 3),

          Tooltip(
            message: 'move up',
            child: _arrowBtn('\u25B2', widget.onMoveUp),
          ),
          const SizedBox(width: 2),
          Tooltip(
            message: 'move down',
            child: _arrowBtn('\u25BC', widget.onMoveDown),
          ),
          const SizedBox(width: 4),

          Tooltip(
            message: 'duplicate step',
            child: _duplicateBtn(),
          ),
          const SizedBox(width: 3),

          Tooltip(
            message: 'delete step',
            child: _deleteBtn(),
          ),
        ],
      ),
    );
  }

  // ---------- mode segment selector ----------

  Widget _modeToggle(StepMode current) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _modeSegment(StepMode.key, 'KEY', RC.neonCyan, current),
        const SizedBox(width: 1),
        _modeSegment(StepMode.text, 'TXT', RC.neonGreen, current),
        const SizedBox(width: 1),
        _modeSegment(StepMode.combo, 'CMB', RC.neonAmber, current),
      ],
    );
  }

  Widget _modeSegment(StepMode mode, String label, Color color, StepMode current) {
    final active = current == mode;
    return GestureDetector(
      onTap: widget.enabled && !active
          ? () {
              setState(() => widget.step.mode = mode);
              widget.onChanged();
            }
          : null,
      child: MouseRegion(
        cursor: widget.enabled && !active
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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

  // ---------- KEY mode body ----------

  Widget _buildKeyBody(KeyStep step) {
    return Column(
      children: [
        // key dropdown row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text('KEY', style: RText.micro.copyWith(
                color: RC.textMuted, letterSpacing: 1.0)),
              const SizedBox(width: 8),
              _PixelDropdown(
                value: step.keyName,
                items: allKeyNames,
                enabled: widget.enabled,
                onChanged: (v) {
                  step.keyName = v;
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),
        // modifiers row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _buildModifiers(step),
        ),
      ],
    );
  }

  // ---------- TEXT mode body ----------

  Widget _buildTextBody(KeyStep step) {
    return Column(
      children: [
        // text input row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text('TXT', style: RText.micro.copyWith(
                color: RC.textMuted, letterSpacing: 1.0)),
              const SizedBox(width: 8),
              Expanded(child: _textField(RC.neonGreen)),
            ],
          ),
        ),
        // Enter toggle row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Text('OPT', style: RText.micro.copyWith(
                color: RC.textMuted, letterSpacing: 1.0)),
              const SizedBox(width: 8),
              PixelToggle(
                label: 'ENTER',
                value: step.appendEnter,
                activeColor: RC.neonGreen,
                onChanged: widget.enabled
                    ? (v) {
                        step.appendEnter = v;
                        widget.onChanged();
                      }
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                step.appendEnter ? 'text then Enter' : 'text only',
                style: RText.micro.copyWith(color: RC.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- COMBO mode body ----------

  Widget _buildComboBody(KeyStep step) {
    return Column(
      children: [
        // combo flow: [prefix key] → [text] → [suffix key]
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              // prefix key toggle + dropdown
              _comboKeySlot(
                label: 'PREFIX',
                enabled: step.hasPrefixKey,
                keyName: step.prefixKeyName,
                onToggle: (v) {
                  step.hasPrefixKey = v;
                  widget.onChanged();
                },
                onKeyChanged: (v) {
                  step.prefixKeyName = v;
                  widget.onChanged();
                },
              ),

              // arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '\u2192',
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 11,
                    color: RC.neonAmber.withValues(alpha: 0.6),
                  ),
                ),
              ),

              // text input (expanded)
              Expanded(child: _textField(RC.neonAmber)),

              // arrow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '\u2192',
                  style: TextStyle(
                    fontFamily: kFontMono,
                    fontSize: 11,
                    color: RC.neonAmber.withValues(alpha: 0.6),
                  ),
                ),
              ),

              // suffix key toggle + dropdown
              _comboKeySlot(
                label: 'SUFFIX',
                enabled: step.hasSuffixKey,
                keyName: step.suffixKeyName,
                onToggle: (v) {
                  step.hasSuffixKey = v;
                  widget.onChanged();
                },
                onKeyChanged: (v) {
                  step.suffixKeyName = v;
                  widget.onChanged();
                },
              ),
            ],
          ),
        ),

        // hint row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            children: [
              Text(
                'FLOW',
                style: RText.micro.copyWith(
                  color: RC.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _comboHint(step),
                  style: RText.micro.copyWith(color: RC.textDim),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// build a hint string describing the combo flow
  String _comboHint(KeyStep step) {
    final parts = <String>[];
    if (step.hasPrefixKey) parts.add(step.prefixKeyName);
    parts.add('text input');
    if (step.hasSuffixKey) parts.add(step.suffixKeyName);
    return parts.join(' \u2192 ');
  }

  /// a toggle + dropdown pair for combo prefix/suffix keys.
  /// dropdown is always visible (disabled when toggle is off) to avoid
  /// jarring layout shifts.
  Widget _comboKeySlot({
    required String label,
    required bool enabled,
    required String keyName,
    required ValueChanged<bool> onToggle,
    required ValueChanged<String> onKeyChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelToggle(
          label: label,
          value: enabled,
          activeColor: RC.neonAmber,
          onChanged: widget.enabled ? onToggle : null,
        ),
        const SizedBox(width: 4),
        Opacity(
          opacity: enabled ? 1.0 : 0.35,
          child: _PixelDropdown(
            value: keyName,
            items: allKeyNames,
            enabled: widget.enabled && enabled,
            onChanged: onKeyChanged,
          ),
        ),
      ],
    );
  }

  // ---------- shared widgets ----------

  Widget _textField(Color accent) {
    return SizedBox(
      height: 22,
      child: TextField(
        controller: _textCtrl,
        enabled: widget.enabled,
        style: RText.body.copyWith(color: accent),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          hintText: 'type text...',
          hintStyle: RText.micro.copyWith(color: RC.textDim),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: RC.border),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: RC.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: accent),
          ),
        ),
        onChanged: (val) {
          widget.step.textContent = val;
          widget.onChanged();
        },
      ),
    );
  }

  Widget _buildModifiers(KeyStep step) {
    return Row(
      children: [
        Text('MOD', style: RText.micro.copyWith(
          color: RC.textMuted, letterSpacing: 1.0)),
        const SizedBox(width: 8),
        _mod('CMD', step.withCommand, (v) {
          step.withCommand = v;
          widget.onChanged();
        }),
        const SizedBox(width: 8),
        _mod('CTL', step.withControl, (v) {
          step.withControl = v;
          widget.onChanged();
        }),
        const SizedBox(width: 8),
        _mod('OPT', step.withOption, (v) {
          step.withOption = v;
          widget.onChanged();
        }),
        const SizedBox(width: 8),
        _mod('SFT', step.withShift, (v) {
          step.withShift = v;
          widget.onChanged();
        }),
      ],
    );
  }

  Widget _mod(String label, bool value, ValueChanged<bool> onToggled) {
    return PixelToggle(
      label: label,
      value: value,
      activeColor: RC.neonCyan,
      onChanged: widget.enabled ? onToggled : null,
    );
  }

  Widget _arrowBtn(String char, VoidCallback? onTap) {
    final active = onTap != null && widget.enabled;
    return GestureDetector(
      onTap: active ? onTap : null,
      child: Container(
        width: 16,
        height: 16,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: active ? RC.textSecond.withValues(alpha: 0.4) : RC.gridLine,
          ),
        ),
        child: Text(
          char,
          style: TextStyle(
            fontFamily: kFontMono,
            fontSize: 8,
            color: active ? RC.textSecond : RC.textMuted,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _duplicateBtn() {
    return GestureDetector(
      onTap: widget.enabled ? widget.onDuplicate : null,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.enabled
                ? RC.neonGreen.withValues(alpha: 0.4)
                : RC.border,
          ),
        ),
        child: Text(
          '\u2398',
          style: TextStyle(
            fontFamily: kFontMono,
            fontSize: 11,
            color: widget.enabled ? RC.neonGreen : RC.textMuted,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _deleteBtn() {
    return GestureDetector(
      onTap: widget.enabled ? widget.onRemove : null,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.enabled
                ? RC.neonMagenta.withValues(alpha: 0.4)
                : RC.border,
          ),
        ),
        child: Text(
          '\u00D7',
          style: TextStyle(
            fontFamily: kFontMono,
            fontSize: 13,
            color: widget.enabled ? RC.neonMagenta : RC.textMuted,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// pixel dropdown
// =============================================================================

class _PixelDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PixelDropdown({
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: RC.bgMid,
        border: Border.all(color: RC.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: RC.bgPanel,
          style: RText.body.copyWith(color: RC.neonPurple),
          icon: Text(
            '\u25BE',
            style: TextStyle(fontFamily: kFontMono, fontSize: 9, color: RC.textDim),
          ),
          items: items.map((name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(name, style: RText.body),
            );
          }).toList(),
          onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
        ),
      ),
    );
  }
}
