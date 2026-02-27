import 'dart:async';
import '../constants/key_codes.dart';
import '../models/key_step.dart';
import '../models/window_info.dart';
import 'native_bridge.dart';

/// state of the key sending service
enum SendingState {
  idle,
  running,
  paused,
}

/// service that manages the periodic sending of key events to a target window.
/// handles the sending loop, window validation, and state management.
class KeySenderService {
  Timer? _sendTimer;
  Timer? _validationTimer;
  int _currentStepIndex = 0;
  int _sendCount = 0;
  SendingState _state = SendingState.idle;

  /// reentrant guard: prevents overlapping async sends when a single
  /// send takes longer than the configured interval.
  bool _isSending = false;

  // configuration
  WindowInfo? _targetWindow;
  List<KeyStep> _steps = [];
  int _intervalMs = 500;

  // repeat mode: 0 = infinite loop, >0 = stop after N full cycles
  int _repeatCount = 0;
  int _cyclesCompleted = 0;

  // callbacks for UI updates
  void Function(int sendCount)? onSendCountChanged;
  void Function(SendingState state)? onStateChanged;
  void Function(String error)? onError;
  void Function()? onWindowInvalid;
  void Function(int cyclesCompleted)? onCycleCompleted;

  /// emitted for every interesting event: key sent, state change, error.
  /// [type] is one of: 'key', 'state', 'error', 'warn'.
  /// [message] is a human-readable description.
  void Function(String type, String message)? onLog;

  SendingState get state => _state;
  int get sendCount => _sendCount;
  WindowInfo? get targetWindow => _targetWindow;
  int get intervalMs => _intervalMs;
  int get repeatCount => _repeatCount;
  int get cyclesCompleted => _cyclesCompleted;

  /// start sending key events to the target window.
  /// validates that the configuration is complete before starting.
  /// [repeatCount] = 0 means infinite loop; >0 = stop after N full cycles.
  void start({
    required WindowInfo targetWindow,
    required List<KeyStep> steps,
    required int intervalMs,
    int repeatCount = 0,
  }) {
    if (steps.isEmpty) {
      onError?.call('no key steps configured');
      return;
    }

    _targetWindow = targetWindow;
    _steps = steps.map((s) => s.copy()).toList();
    _intervalMs = intervalMs;
    _repeatCount = repeatCount;
    _currentStepIndex = 0;
    _sendCount = 0;
    _cyclesCompleted = 0;
    _isSending = false;

    final modeLabel = repeatCount > 0 ? '$repeatCount cycles' : 'infinite';
    _setState(SendingState.running);
    onLog?.call('state', 'START \u2192 ${targetWindow.ownerName}:${targetWindow.pid} '
        '(${steps.length} steps, ${intervalMs}ms, $modeLabel)');
    _startSendLoop();
    _startValidationLoop();
  }

  /// pause sending: cancel the timer to stop CPU-wasteful no-op ticks,
  /// but keep configuration and count intact.
  void pause() {
    if (_state != SendingState.running) return;
    _sendTimer?.cancel();
    _sendTimer = null;
    _setState(SendingState.paused);
    onLog?.call('state', 'PAUSED at count $_sendCount');
  }

  /// resume sending after pause: recreate the timer.
  void resume() {
    if (_state != SendingState.paused) return;
    _setState(SendingState.running);
    onLog?.call('state', 'RESUMED from count $_sendCount');
    _startSendLoop();
  }

  /// stop sending and reset state
  void stop() {
    final count = _sendCount;
    final cycles = _cyclesCompleted;
    _sendTimer?.cancel();
    _sendTimer = null;
    _validationTimer?.cancel();
    _validationTimer = null;
    _sendCount = 0;
    _currentStepIndex = 0;
    _cyclesCompleted = 0;
    _isSending = false;
    _setState(SendingState.idle);
    onLog?.call('state', 'STOPPED (sent: $count, cycles: $cycles)');
  }

  /// clean up resources
  void dispose() {
    _sendTimer?.cancel();
    _validationTimer?.cancel();
  }

  void _setState(SendingState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  /// start the periodic key sending timer
  void _startSendLoop() {
    _sendTimer?.cancel();
    _sendTimer = Timer.periodic(
      Duration(milliseconds: _intervalMs),
      (_) => _sendNextKey(),
    );
  }

  /// start a separate timer to periodically validate the target window
  void _startValidationLoop() {
    _validationTimer?.cancel();
    // validate every 3 seconds to avoid excessive system calls
    _validationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _validateWindow(),
    );
  }

  /// send the next step in the sequence (key press or text input).
  /// guarded by [_isSending] to prevent overlapping when a send takes
  /// longer than the timer interval (the next tick is simply skipped).
  Future<void> _sendNextKey() async {
    if (_state != SendingState.running) return;
    if (_isSending) return;
    if (_targetWindow == null || _steps.isEmpty) return;

    _isSending = true;
    try {
      final step = _steps[_currentStepIndex];

      switch (step.mode) {
        case StepMode.key:
          // -- key mode: single key with modifiers --
          final keyCode = keyCodeMap[step.keyName];
          if (keyCode == null) {
            onError?.call('unknown key: ${step.keyName}');
            return;
          }
          await NativeBridge.sendKeyEvent(
            pid: _targetWindow!.pid,
            keyCode: keyCode,
            modifiers: step.modifierList,
          );

        case StepMode.text:
          // -- text mode: type string, optionally press Enter --
          if (step.textContent.isEmpty) {
            onError?.call('empty text content at step ${_currentStepIndex + 1}');
            return;
          }
          await NativeBridge.sendText(
            pid: _targetWindow!.pid,
            text: step.textContent,
            appendEnter: step.appendEnter,
          );

        case StepMode.combo:
          // -- combo mode: prefix key → text → suffix key --
          if (step.textContent.isEmpty) {
            onError?.call('empty text content at step ${_currentStepIndex + 1}');
            return;
          }
          int? prefixCode;
          if (step.hasPrefixKey) {
            prefixCode = keyCodeMap[step.prefixKeyName];
            if (prefixCode == null) {
              onError?.call('unknown prefix key: ${step.prefixKeyName}');
              return;
            }
          }
          int? suffixCode;
          if (step.hasSuffixKey) {
            suffixCode = keyCodeMap[step.suffixKeyName];
            if (suffixCode == null) {
              onError?.call('unknown suffix key: ${step.suffixKeyName}');
              return;
            }
          }
          await NativeBridge.sendCombo(
            pid: _targetWindow!.pid,
            text: step.textContent,
            prefixKeyCode: prefixCode,
            suffixKeyCode: suffixCode,
          );
      }

      _sendCount++;
      onSendCountChanged?.call(_sendCount);
      onLog?.call('key', '#$_sendCount ${step.displayName} \u2192 PID ${_targetWindow!.pid}');

      // advance to next step in the sequence (loop back to start)
      _currentStepIndex = (_currentStepIndex + 1) % _steps.length;

      // detect cycle completion (step index wrapped back to 0)
      if (_currentStepIndex == 0) {
        _cyclesCompleted++;
        onCycleCompleted?.call(_cyclesCompleted);

        if (_repeatCount > 0 && _cyclesCompleted >= _repeatCount) {
          final totalSent = _sendCount;
          onLog?.call('state',
              'COMPLETED $_cyclesCompleted/$_repeatCount cycles ($totalSent events)');
          stop();
          return;
        }
      }
    } catch (e) {
      onError?.call('send failed: $e');
      onLog?.call('error', 'SEND FAILED: $e');
    } finally {
      _isSending = false;
    }
  }

  /// check if the target window / process still exists.
  /// uses window lookup first, then falls back to PID alive check so that
  /// background, minimized, and other-space windows don't trigger a false alarm.
  Future<void> _validateWindow() async {
    if (_state == SendingState.idle) return;
    if (_targetWindow == null) return;

    final valid = await NativeBridge.isWindowValid(
      _targetWindow!.windowId,
      pid: _targetWindow!.pid,
    );
    if (!valid) {
      onLog?.call('warn',
          'TARGET LOST: process ${_targetWindow!.pid} no longer running');
      pause();
      onWindowInvalid?.call();
    }
  }
}
