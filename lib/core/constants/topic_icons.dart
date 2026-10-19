import 'package:flutter/material.dart';

/// آیکون اختصاصی هر موضوع + رنگ
class TopicVisual {
  final IconData icon;
  final Color color;
  const TopicVisual(this.icon, this.color);
}

const _teal = Color(0xFF1B8578);
const _gold = Color(0xFFC99A2E);
const _purple = Color(0xFF7A5FA8);
const _rose = Color(0xFFB85A72);
const _blue = Color(0xFF3A7CA5);
const _green = Color(0xFF2E9E7B);
const _orange = Color(0xFFD9752E);
const _brown = Color(0xFF8B5E3C);

TopicVisual visualForTopic(String topic) {
  final t = topic.toLowerCase();

  // ═══ روزمره ═══
  if (t.contains('greetings')) return const TopicVisual(Icons.waving_hand_rounded, _teal);
  if (t.contains('introducing people')) return const TopicVisual(Icons.person_add_alt_1_rounded, _purple);
  if (t.contains('visiting an old friend')) return const TopicVisual(Icons.cottage_rounded, _brown);
  if (t.contains('getting acquainted')) return const TopicVisual(Icons.person_search_rounded, _blue);
  if (t.contains('accepting or refusing')) return const TopicVisual(Icons.mark_email_read_rounded, _green);
  if (t.contains('invitations')) return const TopicVisual(Icons.mail_rounded, _gold);
  if (t.contains('saying goodbye')) return const TopicVisual(Icons.door_front_door_rounded, _rose);
  if (t.contains('telephone')) return const TopicVisual(Icons.call_rounded, _teal);
  if (t.contains('transportation')) return const TopicVisual(Icons.directions_bus_rounded, _orange);
  if (t.contains('gas station')) return const TopicVisual(Icons.local_gas_station_rounded, _rose);
  if (t.contains('weather')) return const TopicVisual(Icons.wb_sunny_rounded, _gold);
  if (t.contains('restaurant') || t.contains('café') || t.contains('cafe')) return const TopicVisual(Icons.restaurant_rounded, _orange);
  if (t.contains('shopping (clothes')) return const TopicVisual(Icons.checkroom_rounded, _purple);
  if (t.contains('at a hotel')) return const TopicVisual(Icons.hotel_rounded, _blue);
  if (t.contains('health and doctor')) return const TopicVisual(Icons.medical_services_rounded, _rose);
  if (t.contains('directions') || t.contains('landmarks')) return const TopicVisual(Icons.explore_rounded, _teal);
  if (t.contains('plans and free time') || t.contains('hobbies')) return const TopicVisual(Icons.event_available_rounded, _purple);
  if (t.contains('work and workplace')) return const TopicVisual(Icons.work_rounded, _blue);
  if (t.contains('time and appointments')) return const TopicVisual(Icons.schedule_rounded, _gold);
  if (t.contains('expressing opinions')) return const TopicVisual(Icons.emoji_emotions_rounded, _rose);
  if (t.contains('asking for help')) return const TopicVisual(Icons.help_rounded, _teal);
  if (t.contains('politeness and compliments')) return const TopicVisual(Icons.volunteer_activism_rounded, _rose);
  if (t.contains('travel and experiences')) return const TopicVisual(Icons.travel_explore_rounded, _blue);
  if (t.contains('apologies and forgiveness')) return const TopicVisual(Icons.handshake_rounded, _green);
  if (t.contains('family and cultural')) return const TopicVisual(Icons.family_restroom_rounded, _purple);
  if (t.contains('sports and fitness')) return const TopicVisual(Icons.fitness_center_rounded, _orange);
  if (t.contains('technology and communication')) return const TopicVisual(Icons.devices_other_rounded, _blue);
  if (t.contains('holidays and celebrations')) return const TopicVisual(Icons.celebration_rounded, _gold);
  if (t.contains('pets and animals')) return const TopicVisual(Icons.pets_rounded, _brown);
  if (t.contains('learning a language')) return const TopicVisual(Icons.translate_rounded, _teal);
  if (t.contains('emergency')) return const TopicVisual(Icons.emergency_rounded, _rose);
  if (t.contains('city attractions')) return const TopicVisual(Icons.location_city_rounded, _blue);
  if (t.contains('schools and education')) return const TopicVisual(Icons.school_rounded, _purple);
  if (t.contains('money and expenses')) return const TopicVisual(Icons.account_balance_wallet_rounded, _green);
  if (t.contains('books and reading')) return const TopicVisual(Icons.menu_book_rounded, _brown);
  if (t.contains('environment and nature')) return const TopicVisual(Icons.eco_rounded, _green);
  if (t.contains('cooking and recipes')) return const TopicVisual(Icons.restaurant_menu_rounded, _orange);
  if (t.contains('movies and tv')) return const TopicVisual(Icons.movie_rounded, _purple);
  if (t == 'music' || t.contains('|music|')) return const TopicVisual(Icons.music_note_rounded, _rose);
  if (t.contains('banking and financial')) return const TopicVisual(Icons.account_balance_rounded, _teal);
  if (t.contains('post office')) return const TopicVisual(Icons.local_post_office_rounded, _blue);
  if (t.contains('neighbors and community')) return const TopicVisual(Icons.diversity_3_rounded, _green);
  if (t.contains('future plans and dreams')) return const TopicVisual(Icons.rocket_launch_rounded, _purple);
  if (t.contains('memories and past')) return const TopicVisual(Icons.history_rounded, _brown);

  // ═══ فارسی ═══
  if (topic.contains('طبیعت')) return const TopicVisual(Icons.park_rounded, _green);
  if (topic.contains('احساسات')) return const TopicVisual(Icons.mood_rounded, _rose);
  if (topic.contains('مذهب و سیاست')) return const TopicVisual(Icons.how_to_vote_rounded, _purple);
  if (topic.contains('خرید')) return const TopicVisual(Icons.shopping_cart_rounded, _orange);
  if (topic.contains('علوم')) return const TopicVisual(Icons.science_rounded, _blue);
  if (topic.contains('مسائل اجتماعی')) return const TopicVisual(Icons.public_rounded, _teal);
  if (topic.contains('فناوری')) return const TopicVisual(Icons.memory_rounded, _purple);
  if (topic.contains('سفر و گردشگری')) return const TopicVisual(Icons.flight_takeoff_rounded, _blue);
  if (topic.contains('غذا و آشپزی')) return const TopicVisual(Icons.soup_kitchen_rounded, _orange);
  if (topic.contains('جنگ')) return const TopicVisual(Icons.shield_rounded, _brown);
  if (topic.contains('شغل')) return const TopicVisual(Icons.badge_rounded, _blue);
  if (topic.contains('شخصیت')) return const TopicVisual(Icons.fingerprint_rounded, _rose);
  if (topic.contains('بدن انسان')) return const TopicVisual(Icons.accessibility_new_rounded, _teal);
  if (topic.contains('کسب و کار')) return const TopicVisual(Icons.business_center_rounded, _green);
  if (topic.contains('لباس و مد')) return const TopicVisual(Icons.dry_cleaning_rounded, _purple);
  if (topic.contains('جرم و قانون')) return const TopicVisual(Icons.gavel_rounded, _brown);
  if (topic.contains('فرهنگ')) return const TopicVisual(Icons.theater_comedy_rounded, _rose);
  if (topic.contains('آموزش و تحصیل')) return const TopicVisual(Icons.school_rounded, _purple);
  if (topic.contains('رسانه')) return const TopicVisual(Icons.newspaper_rounded, _blue);
  if (topic.contains('حیوانات')) return const TopicVisual(Icons.pets_rounded, _brown);
  if (topic.contains('خانه')) return const TopicVisual(Icons.cottage_rounded, _orange);

  return const TopicVisual(Icons.chat_bubble_outline_rounded, _teal);
}

/// پس‌زمینه‌ی ملایم آیکون
Color badgeBgColor(Color color) => color.withOpacity(0.12);

/// ۴ رنگ ملایم برای پس‌زمینه‌ی کارت
const List<Color> kTopicBadgeColors = [
  Color(0xFFEAF4F1),
  Color(0xFFFBF0DA),
  Color(0xFFF3ECFB),
  Color(0xFFFBE9E4),
];
