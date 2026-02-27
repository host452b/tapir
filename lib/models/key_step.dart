/// the three modes a step can operate in.
enum StepMode {
  /// send a single key press (with optional modifiers)
  key,

  /// type a string of characters, optionally followed by Enter
  text,

  /// combo: optional prefix key → type text → optional suffix key
  /// designed for chat / dialog automation
  combo,
}

/// represents a single action in a sequence.
class KeyStep {
  StepMode mode;

  // -- key mode fields --
  String keyName;
  bool withCommand;
  bool withShift;
  bool withOption;
  bool withControl;

  // -- text mode fields --
  String textContent;
  bool appendEnter;

  // -- combo mode fields --
  bool hasPrefixKey;
  String prefixKeyName;
  bool hasSuffixKey;
  String suffixKeyName;

  KeyStep({
    this.mode = StepMode.key,
    this.keyName = 'Return',
    this.withCommand = false,
    this.withShift = false,
    this.withOption = false,
    this.withControl = false,
    this.textContent = '',
    this.appendEnter = true,
    this.hasPrefixKey = false,
    this.prefixKeyName = 'Tab',
    this.hasSuffixKey = true,
    this.suffixKeyName = 'Return',
  });

  /// backward-compatible getter
  bool get isTextMode => mode == StepMode.text;

  /// backward-compatible setter
  set isTextMode(bool value) {
    mode = value ? StepMode.text : StepMode.key;
  }

  /// build a human-readable description of this step.
  String get displayName {
    switch (mode) {
      case StepMode.key:
        final parts = <String>[];
        if (withCommand) parts.add('Cmd');
        if (withControl) parts.add('Ctrl');
        if (withOption) parts.add('Opt');
        if (withShift) parts.add('Shift');
        parts.add(keyName);
        return parts.join('+');

      case StepMode.text:
        final preview = textContent.length > 12
            ? '${textContent.substring(0, 12)}..'
            : textContent;
        final suffix = appendEnter ? ' + Enter' : '';
        return '"$preview"$suffix';

      case StepMode.combo:
        final buf = StringBuffer();
        if (hasPrefixKey) {
          buf.write(prefixKeyName);
          buf.write(' \u2192 ');
        }
        final preview = textContent.length > 8
            ? '${textContent.substring(0, 8)}..'
            : textContent;
        buf.write('"$preview"');
        if (hasSuffixKey) {
          buf.write(' \u2192 ');
          buf.write(suffixKeyName);
        }
        return buf.toString();
    }
  }

  /// return the list of modifier names for the native method channel.
  List<String> get modifierList {
    final mods = <String>[];
    if (withCommand) mods.add('command');
    if (withShift) mods.add('shift');
    if (withOption) mods.add('option');
    if (withControl) mods.add('control');
    return mods;
  }

  /// create a deep copy of this step
  KeyStep copy() {
    return KeyStep(
      mode: mode,
      keyName: keyName,
      withCommand: withCommand,
      withShift: withShift,
      withOption: withOption,
      withControl: withControl,
      textContent: textContent,
      appendEnter: appendEnter,
      hasPrefixKey: hasPrefixKey,
      prefixKeyName: prefixKeyName,
      hasSuffixKey: hasSuffixKey,
      suffixKeyName: suffixKeyName,
    );
  }
}
