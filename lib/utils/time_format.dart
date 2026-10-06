/// 列表与详情页共用的时间格式化工具。
library;

String _two(int value) => value.toString().padLeft(2, '0');

/// `yyyy-MM-dd`。
String formatDate(DateTime time) =>
    '${time.year}-${_two(time.month)}-${_two(time.day)}';

/// `yyyy-MM-dd HH:mm`。
String formatDateTime(DateTime time) =>
    '${formatDate(time)} ${_two(time.hour)}:${_two(time.minute)}';

/// 列表卡片右上角的发布时刻，例如“3 小时前”。
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final Duration diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) {
    return '刚刚';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} 分钟前';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小时前';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} 天前';
  }
  return formatDate(time);
}

/// 丢失 / 拾取时刻：当天与前后一天用口语化说法，更早则给日期。
String formatEventTime(DateTime time, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final DateTime today = DateTime(reference.year, reference.month, reference.day);
  final DateTime day = DateTime(time.year, time.month, time.day);
  final int deltaDays = today.difference(day).inDays;
  final String clock = '${_two(time.hour)}:${_two(time.minute)}';

  return switch (deltaDays) {
    0 => '今天 $clock',
    1 => '昨天 $clock',
    2 => '前天 $clock',
    _ => formatDate(time),
  };
}
