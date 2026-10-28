/// هدف و قدمِ پیشنهادیِ «امروز» (کارت «قدم بعدی» آن را می‌نویسد، نقشه می‌خواند).
/// فقط در حافظه است و ذخیره نمی‌شود؛ نقشه هر فریم دوباره کشیده می‌شود،
/// پس نیازی به اعلان تغییر نیست.
class TodayFocus {
  static String goalId = '';
  static String nodeId = '';

  static void update(String goal, String node) {
    goalId = goal;
    nodeId = node;
  }

  static void clear() {
    goalId = '';
    nodeId = '';
  }
}
