/// دسته‌بندی‌های محتوا — معادلِ CATEGORIES/CATEGORIES_EN.
const Map<String, String> kCategoriesFa = {
  'greetings': 'احوال‌پرسی',
  'airport': 'فرودگاه',
  'restaurant': 'رستوران',
  'shopping': 'خرید',
  'hotel': 'هتل',
  'directions': 'جهت‌یابی',
  'emergency': 'اضطراری',
  'numbers': 'اعداد و زمان',
  'meeting': 'ملاقات',
  'introducing': 'معرفی کردن',
  'old_friend': 'دوست قدیمی',
  'acquainted': 'آشنایی',
  'invitation': 'دعوت',
  'goodbye': 'خداحافظی',
  'telephone': 'تلفن',
  'transport': 'حمل‌ونقل',
  'taxi': 'تاکسی',
  'common': 'عبارات رایج',
  'exercises': 'تمرین مکالمه',
  'bus': 'اتوبوس',
  'rental': 'اجاره ماشین',
  'train': 'قطار',
  'gas': 'پمپ بنزین',
  'repair': 'تعمیر ماشین',
};

const Map<String, String> kCategoriesEn = {
  'greetings': 'Greetings',
  'airport': 'Airport',
  'restaurant': 'Restaurant',
  'shopping': 'Shopping',
  'hotel': 'Hotel',
  'directions': 'Directions',
  'emergency': 'Emergency',
  'numbers': 'Numbers & time',
  'meeting': 'Meeting',
  'introducing': 'Introducing',
  'old_friend': 'Old friend',
  'acquainted': 'Getting acquainted',
  'invitation': 'Invitation',
  'goodbye': 'Goodbye',
  'telephone': 'Telephone',
  'transport': 'Transport',
  'taxi': 'Taxi',
  'common': 'Common phrases',
  'exercises': 'Conversation practice',
  'bus': 'Bus',
  'rental': 'Car rental',
  'train': 'Train',
  'gas': 'Gas station',
  'repair': 'Car repair',
};

String categoryLabel(String cat, String uiLang) {
  final table = uiLang == 'en' ? kCategoriesEn : kCategoriesFa;
  return table[cat] ?? cat;
}
