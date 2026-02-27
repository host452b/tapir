import 'package:flutter/material.dart';

// =============================================================================
// retro-futurism color palette
// inspired by 16-bit SNES/Amiga pixel art + cyberpunk neon terminals
// =============================================================================

class RC {
  RC._();

  // -- base backgrounds (dark to light) --
  static const bgDeep    = Color(0xFF08081A);
  static const bgDark    = Color(0xFF0E0E24);
  static const bgMid     = Color(0xFF161636);
  static const bgPanel   = Color(0xFF1C1C42);
  static const bgHover   = Color(0xFF24244E);
  static const bgActive  = Color(0xFF2C2C5A);

  // -- borders & grid --
  static const border       = Color(0xFF2E2E5C);
  static const borderLight  = Color(0xFF3C3C6C);
  static const gridLine     = Color(0xFF1A1A38);

  // -- text hierarchy (wider contrast gaps) --
  static const textBright  = Color(0xFFF0F0FF);
  static const textPrimary = Color(0xFFCCCCEE);
  static const textSecond  = Color(0xFF8888BB);
  static const textDim     = Color(0xFF555588);
  static const textMuted   = Color(0xFF3C3C66);

  // -- neon accents --
  static const neonCyan    = Color(0xFF00E5FF);
  static const neonGreen   = Color(0xFF00FF88);
  static const neonAmber   = Color(0xFFFFB800);
  static const neonMagenta = Color(0xFFFF0080);
  static const neonPurple  = Color(0xFFAA55FF);

  // -- muted accent tints (for backgrounds / soft fills) --
  static const tintCyan    = Color(0xFF0A2A36);
  static const tintGreen   = Color(0xFF0A2A1A);
  static const tintAmber   = Color(0xFF2A2200);
  static const tintMagenta = Color(0xFF2A0A1A);

  // -- semantic --
  static const success = neonGreen;
  static const warning = neonAmber;
  static const error   = neonMagenta;
  static const info    = neonCyan;
}

/// reusable neon glow box shadow for the cyberpunk aesthetic.
/// wrap around any neon-colored element to make it "light up".
List<BoxShadow> neonGlow(Color color, {double intensity = 0.35, double blur = 8}) {
  return [
    BoxShadow(
      color: color.withValues(alpha: intensity),
      blurRadius: blur,
    ),
  ];
}

// =============================================================================
// typography system - 6 tiers with clear size jumps
//
//   display : 24px  hero counters, big metrics
//   title   : 14px  section headers, state labels
//   body    : 12px  standard readable content
//   caption : 10px  field labels, secondary info
//   micro   :  9px  badges, inline tags
//   status  : 10px  status bar items (compact variant)
// =============================================================================

/// exported font family constant for use in widget files
const String kFontMono = 'Menlo';
const List<String> kFontFallback = ['Monaco', 'Courier New', 'monospace'];

// internal alias
const String _fontMono = kFontMono;
const List<String> _fontFallback = kFontFallback;

class RText {
  RText._();

  /// 24px - hero counters, dominant metrics
  static const display = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.0,
    color: RC.textBright,
  );

  /// 14px - panel headers, state labels, section titles
  static const title = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
    color: RC.textBright,
  );

  /// 12px - standard body content (main readable tier)
  static const body = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: RC.textPrimary,
  );

  /// 10px - field labels, categories, secondary annotations
  static const caption = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: RC.textSecond,
  );

  /// 9px - badges, inline tags, minimal annotations
  static const micro = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: RC.textBright,
  );

  /// 10px - status bar compact text
  static const status = TextStyle(
    fontFamily: _fontMono,
    fontFamilyFallback: _fontFallback,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    color: RC.textSecond,
  );

  // -- legacy aliases (kept for backward compatibility) --
  static const header = title;
  static const label  = caption;
  static const small  = caption;
  static const badge  = micro;
}

// =============================================================================
// build the app-wide ThemeData
// =============================================================================

ThemeData buildRetroTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: RC.bgDark,
    fontFamily: _fontMono,
    colorScheme: const ColorScheme.dark(
      primary: RC.neonCyan,
      secondary: RC.neonPurple,
      surface: RC.bgMid,
      error: RC.neonMagenta,
      onPrimary: RC.bgDeep,
      onSecondary: RC.bgDeep,
      onSurface: RC.textPrimary,
      onError: RC.bgDeep,
    ),
    dividerColor: RC.border,
    cardColor: RC.bgPanel,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(RC.border),
      trackColor: WidgetStateProperty.all(RC.bgDeep),
      radius: Radius.zero,
      thickness: WidgetStateProperty.all(6),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: RC.bgPanel,
        border: Border.all(color: RC.neonCyan, width: 1),
      ),
      textStyle: RText.caption.copyWith(color: RC.neonCyan),
    ),
  );
}

// =============================================================================
// reusable pixel-style widget components
// =============================================================================

/// panel container with retro border and colored top accent line.
/// uses `title` tier for header text (14px) to stand out from body content.
class PixelPanel extends StatelessWidget {
  final Widget child;
  final String? header;
  final Color accentColor;
  final EdgeInsets padding;

  const PixelPanel({
    super.key,
    required this.child,
    this.header,
    this.accentColor = RC.neonCyan,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: RC.bgMid,
        border: Border(
          top: BorderSide(color: accentColor, width: 2),
          left: BorderSide(color: RC.border, width: 1),
          right: BorderSide(color: RC.border, width: 1),
          bottom: BorderSide(color: RC.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: const Border(
                  bottom: BorderSide(color: RC.border, width: 1),
                ),
              ),
              child: Text(
                header!,
                style: RText.caption.copyWith(
                  color: accentColor,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// retro button with 3D embossed pixel border.
class PixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;
  final IconData? icon;
  final bool compact;

  const PixelButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = RC.neonCyan,
    this.filled = false,
    this.icon,
    this.compact = false,
  });

  @override
  State<PixelButton> createState() => _PixelButtonState();
}

class _PixelButtonState extends State<PixelButton> {
  bool _pressed = false;
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final baseColor = enabled ? widget.color : RC.textMuted;

    final highlight = _pressed ? RC.bgDeep : baseColor.withValues(alpha: 0.65);
    final shadow = _pressed ? baseColor.withValues(alpha: 0.65) : RC.bgDeep;

    final hPad = widget.compact ? 8.0 : 10.0;
    final vPad = widget.compact ? 4.0 : 5.0;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => setState(() => _hovering = true) : null,
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: _hovering && enabled
                ? (widget.filled
                    ? baseColor.withValues(alpha: 0.30)
                    : RC.bgActive)
                : (widget.filled
                    ? baseColor.withValues(alpha: 0.22)
                    : RC.bgHover),
            border: Border(
              top: BorderSide(color: highlight, width: 1),
              left: BorderSide(color: highlight, width: 1),
              bottom: BorderSide(color: shadow, width: 1),
              right: BorderSide(color: shadow, width: 1),
            ),
            boxShadow: _hovering && enabled
                ? neonGlow(baseColor, intensity: 0.25, blur: 10)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 12, color: baseColor),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: RText.caption.copyWith(
                  color: enabled
                      ? (_hovering ? baseColor : RC.textBright)
                      : RC.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// compact colored badge with sharp corners
class PixelBadge extends StatelessWidget {
  final String text;
  final Color color;

  const PixelBadge({
    super.key,
    required this.text,
    this.color = RC.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        text,
        style: RText.micro.copyWith(color: color),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}

/// retro toggle: pixel checkbox [x] or [ ] with label
class PixelToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  const PixelToggle({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.activeColor = RC.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;

    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: value ? activeColor.withValues(alpha: 0.15) : RC.bgDeep,
              border: Border.all(
                color: value ? activeColor : RC.border,
                width: 1,
              ),
              boxShadow: value
                  ? neonGlow(activeColor, intensity: 0.3, blur: 6)
                  : null,
            ),
            alignment: Alignment.center,
            child: value
                ? Text(
                    'x',
                    style: TextStyle(
                      fontFamily: _fontMono,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: activeColor,
                      height: 1.0,
                    ),
                  )
                : null,
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: RText.caption.copyWith(
                color: enabled
                    ? (value ? activeColor : RC.textSecond)
                    : RC.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// thin horizontal line divider with optional label
class PixelDivider extends StatelessWidget {
  final String? label;
  final Color color;

  const PixelDivider({super.key, this.label, this.color = RC.border});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Container(height: 1, color: color);
    }
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label!,
            style: RText.micro.copyWith(color: RC.textMuted),
          ),
        ),
        Expanded(child: Container(height: 1, color: color)),
      ],
    );
  }
}

/// styled text input field with retro pixel borders
class PixelInput extends StatelessWidget {
  final String? hintText;
  final String? initialValue;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final double width;

  const PixelInput({
    super.key,
    this.hintText,
    this.initialValue,
    this.keyboardType,
    this.onChanged,
    this.width = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: RText.body.copyWith(color: RC.neonCyan),
        cursorColor: RC.neonCyan,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: RText.body.copyWith(color: RC.textMuted),
          filled: true,
          fillColor: RC.bgDeep,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          isDense: true,
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
      ),
    );
  }
}
