import 'package:flutter/services.dart';
import '../models/window_info.dart';

/// bridge to the native macOS layer via FlutterMethodChannel.
/// handles window scanning, key event sending, and permission checks.
class NativeBridge {
  static const _channel = MethodChannel('com.tapir/native');

  /// scan all visible windows on the system.
  /// returns a list of WindowInfo objects.
  static Future<List<WindowInfo>> getWindows() async {
    try {
      final result = await _channel.invokeMethod('getWindows');
      if (result == null) return [];

      final list = List<Map<dynamic, dynamic>>.from(result);
      return list.map((item) {
        final map = Map<String, dynamic>.from(item);
        return WindowInfo.fromMap(map);
      }).toList();
    } on PlatformException catch (e) {
      throw Exception('failed to get windows: ${e.message}');
    }
  }

  /// check if accessibility permission is granted.
  static Future<bool> checkAccessibility() async {
    try {
      final result = await _channel.invokeMethod('checkAccessibility');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// request accessibility permission from the user.
  /// this will open the system preferences dialog.
  static Future<void> requestAccessibility() async {
    try {
      await _channel.invokeMethod('requestAccessibility');
    } on PlatformException catch (e) {
      throw Exception('failed to request accessibility: ${e.message}');
    }
  }

  /// send a key event to the specified process.
  /// [pid] - target process id
  /// [keyCode] - macOS virtual key code
  /// [modifiers] - list of modifier names ("command", "shift", "option", "control")
  static Future<bool> sendKeyEvent({
    required int pid,
    required int keyCode,
    List<String> modifiers = const [],
  }) async {
    try {
      final result = await _channel.invokeMethod('sendKeyEvent', {
        'pid': pid,
        'keyCode': keyCode,
        'modifiers': modifiers,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('failed to send key event: ${e.message}');
    }
  }

  /// send a text string (character by character) to the specified process.
  /// optionally appends an Enter key press at the end.
  /// [pid] - target process id
  /// [text] - the string to type
  /// [appendEnter] - whether to press Enter after the text
  static Future<bool> sendText({
    required int pid,
    required String text,
    bool appendEnter = false,
  }) async {
    try {
      final result = await _channel.invokeMethod('sendText', {
        'pid': pid,
        'text': text,
        'appendEnter': appendEnter,
      });
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('failed to send text: ${e.message}');
    }
  }

  /// send a combo sequence: optional prefix key → text → optional suffix key.
  /// designed for chat/dialog automation (e.g., Tab → "hello" → Enter).
  /// [pid] - target process id
  /// [text] - the string to type
  /// [prefixKeyCode] - key code to press before text (null = skip)
  /// [suffixKeyCode] - key code to press after text (null = skip)
  static Future<bool> sendCombo({
    required int pid,
    required String text,
    int? prefixKeyCode,
    int? suffixKeyCode,
  }) async {
    try {
      final args = <String, dynamic>{
        'pid': pid,
        'text': text,
      };
      if (prefixKeyCode != null) args['prefixKeyCode'] = prefixKeyCode;
      if (suffixKeyCode != null) args['suffixKeyCode'] = suffixKeyCode;

      final result = await _channel.invokeMethod('sendCombo', args);
      return result == true;
    } on PlatformException catch (e) {
      throw Exception('failed to send combo: ${e.message}');
    }
  }

  /// check if a window with the given id still exists (any state).
  /// also checks process alive as fallback when the window is gone.
  static Future<bool> isWindowValid(int windowId, {int? pid}) async {
    try {
      final args = <String, dynamic>{'windowId': windowId};
      if (pid != null) args['pid'] = pid;
      final result = await _channel.invokeMethod('isWindowValid', args);
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// check if a process with the given pid is still running.
  static Future<bool> isProcessAlive(int pid) async {
    try {
      final result = await _channel.invokeMethod('isProcessAlive', {
        'pid': pid,
      });
      return result == true;
    } on PlatformException {
      return false;
    }
  }
}
