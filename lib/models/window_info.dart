/// represents a macOS window discovered by the native window scanner.
/// includes process hierarchy information (parent/child relationships).
class WindowInfo {
  final int windowId;
  final String ownerName;
  final String windowName;
  final int pid;
  final int parentPid;

  /// true if this window's process is a child of another windowed process
  final bool isChildProcess;

  /// the pid of the parent windowed process (only set if isChildProcess == true)
  final int parentWindowedPid;

  /// how many child processes (that also have windows) belong to this process
  final int childProcessCount;

  /// how many windows this same pid owns (detects multi-window processes)
  final int subWindowCount;

  /// true if the window is currently visible on screen (not minimized, not on another space)
  final bool isOnScreen;

  const WindowInfo({
    required this.windowId,
    required this.ownerName,
    required this.windowName,
    required this.pid,
    required this.parentPid,
    this.isChildProcess = false,
    this.parentWindowedPid = 0,
    this.childProcessCount = 0,
    this.subWindowCount = 1,
    this.isOnScreen = true,
  });

  /// create from the dictionary returned by the native method channel.
  factory WindowInfo.fromMap(Map<String, dynamic> map) {
    return WindowInfo(
      windowId: map['windowId'] as int,
      ownerName: map['ownerName'] as String,
      windowName: map['windowName'] as String,
      pid: map['pid'] as int,
      parentPid: map['parentPid'] as int? ?? 0,
      isChildProcess: map['isChildProcess'] as bool? ?? false,
      parentWindowedPid: map['parentWindowedPid'] as int? ?? 0,
      childProcessCount: map['childProcessCount'] as int? ?? 0,
      subWindowCount: map['subWindowCount'] as int? ?? 1,
      isOnScreen: map['isOnScreen'] as bool? ?? true,
    );
  }

  /// short display label: "AppName - WindowTitle"
  String get displayName {
    if (windowName.isEmpty) {
      return ownerName;
    }
    return '$ownerName - $windowName';
  }

  /// tag string describing process hierarchy role.
  /// e.g., "parent (2 children)" or "child of PID 1234"
  String get hierarchyTag {
    final parts = <String>[];

    if (childProcessCount > 0) {
      parts.add('$childProcessCount child proc');
    }
    if (isChildProcess) {
      parts.add('child of PID $parentWindowedPid');
    }
    if (subWindowCount > 1) {
      parts.add('$subWindowCount windows');
    }

    if (parts.isEmpty) return '';
    return parts.join(' | ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WindowInfo && other.windowId == windowId;
  }

  @override
  int get hashCode => windowId.hashCode;

  @override
  String toString() {
    return 'WindowInfo(id: $windowId, owner: $ownerName, name: $windowName, '
        'pid: $pid, ppid: $parentPid, child: $isChildProcess)';
  }
}
