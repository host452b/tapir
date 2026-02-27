import 'package:flutter/material.dart';
import '../models/window_info.dart';
import '../services/native_bridge.dart';
import '../theme/retro_theme.dart';

/// window scanner + selector: list rows with tight density.
/// title-level selected name, body-level list names,
/// micro-level PID/hierarchy badges.
class WindowSelector extends StatefulWidget {
  final WindowInfo? selectedWindow;
  final ValueChanged<WindowInfo?> onWindowSelected;
  final bool enabled;

  const WindowSelector({
    super.key,
    required this.selectedWindow,
    required this.onWindowSelected,
    this.enabled = true,
  });

  @override
  State<WindowSelector> createState() => _WindowSelectorState();
}

class _WindowSelectorState extends State<WindowSelector> {
  List<WindowInfo> _windows = [];
  bool _isLoading = false;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshWindows();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WindowInfo> get _filteredWindows {
    if (_searchQuery.isEmpty) return _windows;
    final query = _searchQuery.toLowerCase();
    return _windows.where((w) {
      return w.ownerName.toLowerCase().contains(query) ||
          w.windowName.toLowerCase().contains(query) ||
          w.pid.toString().contains(query);
    }).toList();
  }

  Future<void> _refreshWindows() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final windows = await NativeBridge.getWindows();
      if (!mounted) return;

      setState(() {
        _windows = windows;
        _isLoading = false;
      });

      if (widget.selectedWindow != null) {
        final stillExists = windows.any(
          (w) => w.windowId == widget.selectedWindow!.windowId,
        );
        if (!stillExists) {
          widget.onWindowSelected(null);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header bar: scan + count + lock status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: RC.bgMid,
            border: Border(
              top: BorderSide(color: RC.neonCyan, width: 1),
              left: BorderSide(color: RC.border, width: 1),
              right: BorderSide(color: RC.border, width: 1),
              bottom: BorderSide(color: RC.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              PixelButton(
                label: _isLoading ? 'SCANNING...' : 'SCAN',
                icon: Icons.radar,
                color: RC.neonCyan,
                compact: true,
                onPressed: widget.enabled && !_isLoading
                    ? _refreshWindows
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                '${_filteredWindows.length}',
                style: RText.body.copyWith(
                  color: _windows.isEmpty ? RC.textDim : RC.neonCyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                Text(
                  '/${_windows.length}',
                  style: RText.micro.copyWith(color: RC.textDim),
                ),
              ],
              const SizedBox(width: 3),
              Text(
                'FOUND',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
              const Spacer(),
              if (widget.selectedWindow != null) ...[
                PixelBadge(text: 'SELECTED', color: RC.neonGreen),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'deselect window',
                  child: GestureDetector(
                    onTap: widget.enabled
                        ? () => widget.onWindowSelected(null)
                        : null,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: RC.neonMagenta.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '\u00D7',
                        style: TextStyle(
                          fontFamily: kFontMono,
                          fontSize: 12,
                          color: widget.enabled
                              ? RC.neonMagenta
                              : RC.textMuted,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: const BoxDecoration(
            color: RC.bgDeep,
            border: Border(
              left: BorderSide(color: RC.border, width: 1),
              right: BorderSide(color: RC.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                '\u2315',
                style: TextStyle(
                  fontFamily: kFontMono,
                  fontSize: 12,
                  color: _searchQuery.isNotEmpty
                      ? RC.neonCyan
                      : RC.textMuted,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 22,
                  child: TextField(
                    controller: _searchController,
                    style: RText.body.copyWith(color: RC.neonCyan),
                    cursorColor: RC.neonCyan,
                    decoration: InputDecoration(
                      hintText: 'filter by name or pid...',
                      hintStyle: RText.micro.copyWith(color: RC.textMuted),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: RC.border),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: RC.border),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: RC.neonCyan),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim());
                    },
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: RC.neonMagenta.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '\u00D7',
                      style: TextStyle(
                        fontFamily: kFontMono,
                        fontSize: 12,
                        color: RC.neonMagenta,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // error display
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: RC.tintMagenta,
            child: Text(
              'ERR: $_errorMessage',
              style: RText.caption.copyWith(color: RC.neonMagenta),
            ),
          ),

        // window list
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: RC.bgDeep,
              border: Border(
                left: BorderSide(color: RC.border, width: 1),
                right: BorderSide(color: RC.border, width: 1),
                bottom: BorderSide(color: RC.border, width: 1),
              ),
            ),
            child: _filteredWindows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isLoading ? '\u21BB' : '\u2014',
                          style: TextStyle(fontSize: 18, color: RC.textMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isLoading
                              ? 'SCANNING WINDOWS...'
                              : _searchQuery.isNotEmpty
                                  ? 'NO MATCH FOR "$_searchQuery"'
                                  : 'NO WINDOWS DETECTED',
                          style: RText.caption.copyWith(color: RC.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredWindows.length,
                    itemBuilder: (context, index) {
                      final window = _filteredWindows[index];
                      final isSelected =
                          widget.selectedWindow?.windowId == window.windowId;

                      return _WindowRow(
                        window: window,
                        isSelected: isSelected,
                        enabled: widget.enabled,
                        onTap: () {
                          if (!widget.enabled) return;
                          if (isSelected) {
                            widget.onWindowSelected(null);
                          } else {
                            widget.onWindowSelected(window);
                          }
                        },
                      );
                    },
                  ),
          ),
        ),

        // selected window detail
        if (widget.selectedWindow != null) ...[
          const SizedBox(height: 3),
          _buildSelectedDetail(widget.selectedWindow!),
        ],
      ],
    );
  }

  Widget _buildSelectedDetail(WindowInfo w) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: RC.tintCyan,
        border: const Border(
          left: BorderSide(color: RC.neonCyan, width: 3),
          top: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: RC.neonCyan.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            w.displayName,
            style: RText.title.copyWith(
              color: RC.neonCyan,
              fontSize: 13,
              shadows: [
                Shadow(
                  color: RC.neonCyan.withValues(alpha: 0.4),
                  blurRadius: 6,
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    PixelBadge(text: 'PID ${w.pid}', color: RC.neonCyan),
                    PixelBadge(text: 'PPID ${w.parentPid}', color: RC.textDim),
                    if (!w.isOnScreen)
                      PixelBadge(text: 'BACKGROUND', color: RC.neonAmber),
                    if (w.childProcessCount > 0)
                      PixelBadge(
                        text: '${w.childProcessCount} CHILD',
                        color: RC.neonAmber,
                      ),
                    if (w.subWindowCount > 1)
                      PixelBadge(
                        text: '${w.subWindowCount} WIN',
                        color: RC.neonPurple,
                      ),
                  ],
                ),
              ),
              if (widget.enabled)
                PixelButton(
                  label: 'DESELECT',
                  color: RC.neonMagenta,
                  compact: true,
                  onPressed: () => widget.onWindowSelected(null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// window list row - tight vertical spacing, clear name/metadata contrast
// =============================================================================

class _WindowRow extends StatefulWidget {
  final WindowInfo window;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _WindowRow({
    required this.window,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends State<_WindowRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.window;
    final tag = w.hierarchyTag;

    Color bg;
    if (widget.isSelected) {
      bg = RC.neonCyan.withValues(alpha: 0.08);
    } else if (_hovering) {
      bg = RC.bgHover;
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: widget.isSelected
                    ? RC.neonCyan
                    : (_hovering ? RC.neonCyan.withValues(alpha: 0.3) : Colors.transparent),
                width: 2,
              ),
              bottom: const BorderSide(color: RC.gridLine, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? RC.neonCyan.withValues(alpha: 0.15)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? RC.neonCyan
                        : (_hovering ? RC.textDim : RC.gridLine),
                    width: 1,
                  ),
                  boxShadow: widget.isSelected
                      ? neonGlow(RC.neonCyan, intensity: 0.4, blur: 4)
                      : null,
                ),
                child: widget.isSelected
                    ? Container(
                        width: 4,
                        height: 4,
                        color: RC.neonCyan,
                      )
                    : null,
              ),

              // child process indent
              if (w.isChildProcess)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: Text(
                    '\u2514',
                    style: TextStyle(
                      fontFamily: kFontMono,
                      fontSize: 11,
                      color: RC.textMuted,
                    ),
                  ),
                ),

              // name + tag
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // window name (body tier - readable)
                    Text(
                      w.displayName,
                      style: RText.body.copyWith(
                        color: widget.isSelected
                            ? RC.neonCyan
                            : RC.textPrimary,
                        fontWeight: widget.isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    // hierarchy tag (micro tier - dimmer, much smaller)
                    if (tag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          tag,
                          style: RText.micro.copyWith(color: RC.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),

              if (!w.isOnScreen)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: PixelBadge(text: 'BG', color: RC.neonAmber),
                ),

              if (w.childProcessCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: PixelBadge(
                    text: '${w.childProcessCount}ch',
                    color: RC.neonAmber,
                  ),
                ),
              if (w.subWindowCount > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: PixelBadge(
                    text: '${w.subWindowCount}w',
                    color: RC.neonPurple,
                  ),
                ),
              PixelBadge(text: '${w.pid}', color: RC.textSecond),
            ],
          ),
        ),
      ),
    );
  }
}
