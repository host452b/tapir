import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../theme/retro_theme.dart';

/// system page: permission + system info merged, troubleshooting collapsible.
/// size contrast: title-level status, body-level values, micro-level labels.
class PermissionBanner extends StatefulWidget {
  final VoidCallback? onPermissionChanged;

  const PermissionBanner({super.key, this.onPermissionChanged});

  @override
  State<PermissionBanner> createState() => _PermissionBannerState();
}

class _PermissionBannerState extends State<PermissionBanner> {
  bool _hasPermission = false;
  bool _isChecking = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isChecking = true);
    final granted = await NativeBridge.checkAccessibility();
    if (!mounted) return;
    setState(() {
      _hasPermission = granted;
      _isChecking = false;
    });
    widget.onPermissionChanged?.call();
  }

  Future<void> _requestPermission() async {
    await NativeBridge.requestAccessibility();
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- permission + system info --
        PixelPanel(
          header: 'SYSTEM',
          accentColor: RC.neonAmber,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // permission status - prominent
              Container(
                padding: const EdgeInsets.all(10),
                color: _hasPermission ? RC.tintGreen : RC.tintMagenta,
                child: Row(
                  children: [
                    // status dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor(),
                        border: Border.all(color: _statusColor(), width: 1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // status text (title tier - 14px, dominant)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusLabel(),
                            style: RText.title.copyWith(
                              color: _statusColor(),
                              fontSize: 13,
                            ),
                          ),
                          // description (caption tier - 10px, recessive)
                          Text(
                            _hasPermission
                                ? 'Key events can be sent to other processes.'
                                : 'Grant in System Settings > Privacy & Security > Accessibility.',
                            style: RText.caption.copyWith(
                              color: RC.textSecond,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (!_hasPermission) ...[
                      PixelButton(
                        label: 'GRANT',
                        color: RC.neonAmber,
                        filled: true,
                        compact: true,
                        onPressed: _requestPermission,
                      ),
                      const SizedBox(width: 4),
                    ],
                    PixelButton(
                      label: 'CHECK',
                      color: RC.neonAmber,
                      compact: true,
                      onPressed: _checkPermission,
                    ),
                  ],
                ),
              ),
              const PixelDivider(),

              // system info grid - two columns, compact
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _infoRow('PLATFORM', 'macOS'),
                          const SizedBox(height: 3),
                          _infoRow('ENGINE', 'CGEvent'),
                          const SizedBox(height: 3),
                          _infoRow('METHOD', 'postToPid()'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _infoRow('SANDBOX', 'DISABLED'),
                          const SizedBox(height: 3),
                          _infoRow('TARGET', 'PID-level'),
                          const SizedBox(height: 3),
                          _infoRow('API', 'Accessibility'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // -- troubleshooting (collapsible) --
        Container(
          decoration: const BoxDecoration(
            color: RC.bgMid,
            border: Border(
              left: BorderSide(color: RC.border, width: 1),
              right: BorderSide(color: RC.border, width: 1),
              bottom: BorderSide(color: RC.border, width: 1),
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showHelp = !_showHelp),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: RC.bgDeep,
                    border: Border(
                      top: BorderSide(color: RC.neonAmber, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _showHelp ? '\u25BC' : '\u25B6',
                        style: TextStyle(
                          fontFamily: kFontMono,
                          fontSize: 9,
                          color: RC.neonAmber,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TROUBLESHOOTING',
                        style: RText.caption.copyWith(
                          color: RC.neonAmber,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showHelp)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    '> Permission NOT GRANTED after granting:\n'
                    '  Run: tccutil reset Accessibility\n'
                    '  Then restart and re-grant.\n'
                    '\n'
                    '> Keys not received by target:\n'
                    '  1. Verify window is visible\n'
                    '  2. Check PID in TARGET tab\n'
                    '  3. Some apps block external events\n'
                    '\n'
                    '> Multi-window apps:\n'
                    '  Keys go to process (PID), the process\n'
                    '  routes to its key/front window.',
                    style: RText.body.copyWith(
                      color: RC.textSecond,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _statusColor() {
    if (_isChecking) return RC.textDim;
    return _hasPermission ? RC.neonGreen : RC.neonMagenta;
  }

  String _statusLabel() {
    if (_isChecking) return 'CHECKING...';
    return _hasPermission ? 'GRANTED' : 'NOT GRANTED';
  }

  /// info row: micro label (9px) + body value (12px) = 3px contrast gap
  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: RText.micro.copyWith(color: RC.textMuted, letterSpacing: 0.8),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: RText.body.copyWith(color: RC.neonAmber),
          ),
        ),
      ],
    );
  }
}
