import 'package:flutter/material.dart';
import '../theme/retro_theme.dart';

/// a single log entry with timestamp, type tag, and message.
class LogEntry {
  final DateTime timestamp;

  /// one of: 'key', 'state', 'error', 'warn'
  final String type;
  final String message;

  const LogEntry({
    required this.timestamp,
    required this.type,
    required this.message,
  });

  /// color based on log type
  Color get color {
    return switch (type) {
      'key' => RC.neonCyan,
      'state' => RC.neonGreen,
      'error' => RC.neonMagenta,
      'warn' => RC.neonAmber,
      _ => RC.textSecond,
    };
  }

  /// short type label for display
  String get tag {
    return switch (type) {
      'key' => 'KEY',
      'state' => 'SYS',
      'error' => 'ERR',
      'warn' => 'WRN',
      _ => '---',
    };
  }
}

/// maximum number of log entries to keep in memory
const int kMaxLogEntries = 500;

/// retro terminal-style scrollable event log.
/// auto-scrolls to bottom on new entries.
class EventLog extends StatefulWidget {
  final List<LogEntry> entries;
  final VoidCallback? onClear;

  const EventLog({
    super.key,
    required this.entries,
    this.onClear,
  });

  @override
  State<EventLog> createState() => _EventLogState();
}

class _EventLogState extends State<EventLog> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void didUpdateWidget(EventLog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // auto-scroll to bottom when new entries arrive
    if (_autoScroll && widget.entries.length > oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollNotification() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // disable auto-scroll if user scrolled up, re-enable at bottom
    _autoScroll = pos.pixels >= pos.maxScrollExtent - 20;
  }

  /// format timestamp as MM-DD HH:MM:SS
  String _formatTime(DateTime t) {
    final mo = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final h = t.hour.toString().padLeft(2, '0');
    final mi = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$mo-$d $h:$mi:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const BoxDecoration(
            color: RC.bgDeep,
            border: Border(
              top: BorderSide(color: RC.neonGreen, width: 1),
              left: BorderSide(color: RC.border, width: 1),
              right: BorderSide(color: RC.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Text(
                'EVENT LOG',
                style: RText.caption.copyWith(
                  color: RC.neonGreen,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.entries.length}',
                style: RText.body.copyWith(
                  color: RC.neonGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                'ENTRIES',
                style: RText.micro.copyWith(color: RC.textMuted),
              ),
              const Spacer(),
              PixelToggle(
                label: 'AUTO',
                value: _autoScroll,
                activeColor: RC.neonGreen,
                onChanged: (v) {
                  setState(() => _autoScroll = v);
                  if (v && _scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                },
              ),
              const SizedBox(width: 6),
              PixelButton(
                label: 'CLEAR',
                color: RC.neonMagenta,
                compact: true,
                onPressed: widget.onClear,
              ),
            ],
          ),
        ),

        // log content
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              _onScrollNotification();
              return false;
            },
            child: Container(
              decoration: const BoxDecoration(
                color: RC.bgDeep,
                border: Border(
                  left: BorderSide(color: RC.border, width: 1),
                  right: BorderSide(color: RC.border, width: 1),
                  bottom: BorderSide(color: RC.border, width: 1),
                ),
              ),
              child: widget.entries.isEmpty
                  ? Center(
                      child: Text(
                        'no events yet',
                        style: RText.caption.copyWith(color: RC.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: widget.entries.length,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      itemBuilder: (context, index) {
                        return _buildLogRow(widget.entries[index], index);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogRow(LogEntry entry, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: index.isEven ? Colors.transparent : RC.bgDark.withValues(alpha: 0.3),
        border: const Border(
          bottom: BorderSide(color: RC.gridLine, width: 1),
        ),
      ),
      child: Row(
        children: [
          // timestamp
          Text(
            _formatTime(entry.timestamp),
            style: RText.micro.copyWith(
              color: RC.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          // type tag
          Container(
            width: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 1),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.12),
              border: Border.all(
                color: entry.color.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              entry.tag,
              style: RText.micro.copyWith(
                color: entry.color,
                fontSize: 8,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // message
          Expanded(
            child: Text(
              entry.message,
              style: RText.body.copyWith(
                color: entry.color,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
