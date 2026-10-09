/// 时间格式化（`lib/utils/time_format.dart`）用到的措辞。
///
/// 相对时间的文案是**拼出来的**（「3 小时前」），所以这里既给出后缀常量
/// （测试断言「带不带小时前」时用它），也给出拼装函数（界面用它，
/// 保证两处拼法一致）。
abstract final class TimeStrings {
  static const String justNow = '刚刚';
  static const String minutesAgoUnit = '分钟前';
  static const String hoursAgoUnit = '小时前';
  static const String daysAgoUnit = '天前';
  static const String today = '今天';
  static const String yesterday = '昨天';
  static const String beforeYesterday = '前天';

  static String minutesAgo(int minutes) => '$minutes $minutesAgoUnit';

  static String hoursAgo(int hours) => '$hours $hoursAgoUnit';

  static String daysAgo(int days) => '$days $daysAgoUnit';

  static String todayAt(String clock) => '$today $clock';

  static String yesterdayAt(String clock) => '$yesterday $clock';

  static String beforeYesterdayAt(String clock) => '$beforeYesterday $clock';
}
