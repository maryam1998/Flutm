import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/widgets/sync_item_card.dart';

// اجزای قدیمی از همین مسیر هم در دسترس می‌مانند
export '../../../core/widgets/sync_item_card.dart'
    show AiExamplesButton, NeuralPathButton;

// ═══════════════════════════════════════════════════════════════════
// WordCard — فقط یک پوسته‌ی نازک روی کارتِ مشترکِ برنامه (SyncItemCard).
// ظاهر، ترجمه، هایلایت و اسکرول همه در همان کارتِ مشترک‌اند و با
// تبِ مکالمات یکسان کار می‌کنند.
// ═══════════════════════════════════════════════════════════════════
class WordCard extends StatelessWidget {
  final String id;
  final String en;
  final String fa;
  final String level;
  final String pos;
  final List<String> langsToShow;
  final bool isPersonal;
  final Map<String, String> knownTranslations;

  /// ✕ برای لغات شخصی (فقط از تبِ دیکشنری من پنهان می‌کند).
  final VoidCallback? onRemove;

  final bool isRead;
  final VoidCallback? onToggleRead;

  const WordCard({
    super.key,
    required this.id,
    required this.en,
    required this.fa,
    required this.level,
    required this.pos,
    required this.langsToShow,
    this.isPersonal = false,
    this.knownTranslations = const <String, String>{},
    this.onRemove,
    this.isRead = false,
    this.onToggleRead,
  });

  @override
  Widget build(BuildContext context) {
    final known = <String, String>{...knownTranslations};
    if (fa.isNotEmpty && !known.containsKey('fa')) known['fa'] = fa;

    return SyncItemCard(
      id: id,
      en: en,
      level: level,
      pos: _posLabel(context, pos),
      isPersonal: isPersonal,
      langsToShow: langsToShow,
      knownTranslations: known,
      compact: false,
      showActions: true,
      onRemove: onRemove,
      isRead: isRead,
      onToggleRead: onToggleRead,
    );
  }

  /// برچسبِ نوعِ کلمه به زبانِ رابطِ برنامه. «other» و «slang» اصلاً نمایش
  /// داده نمی‌شوند.
  static String _posLabel(BuildContext context, String pos) {
    final L = context.l10n;
    switch (pos) {
      case 'noun': return L.pos_noun;
      case 'verb': return L.pos_verb;
      case 'adjective': return L.pos_adjective;
      case 'adverb': return L.pos_adverb;
      case 'preposition': return L.pos_preposition;
      case 'pronoun': return L.pos_pronoun;
      case 'conjunction': return L.pos_conjunction;
      case 'article': return L.pos_article;
      case 'interjection': return L.pos_interjection;
      case 'numeral': return L.pos_numeral;
      case 'auxiliary': return L.pos_auxiliary;
      case 'determiner': return L.pos_determiner;
      case 'exclamation': return L.pos_exclamation;
      case 'idiom': return L.pos_idiom;
      case 'other':
      case 'slang':
      case '':
        return '';
      default:
        return pos;
    }
  }
}
