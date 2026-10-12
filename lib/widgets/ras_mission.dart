import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/beliefs_store.dart';

const _kEmerald500 = Color(0xFF2BBFAB);
const _kEmerald700 = Color(0xFF0F5B53);
const _kGold500 = Color(0xFFC9972B);
const _kMuted = Color(0xFF7A6B57);
const _kBorder = Color(0xFFE0D5C0);
const _kCard = Colors.white;
const _kInk = Color(0xFF2A2218);
const _kCream = Color(0xFFFBF6EA);

class RasMissionChip {
  final String id;
  final String label;
  final String emoji;
  const RasMissionChip({required this.id, required this.label, required this.emoji});
}

const List<RasMissionChip> kRasMissions = [
  RasMissionChip(id: 'opportunity', label: 'فرصت‌های کوچیک', emoji: '✨'),
  RasMissionChip(id: 'calm',        label: 'لحظه‌های آرامش',  emoji: '😌'),
  RasMissionChip(id: 'beauty',      label: 'زیبایی',           emoji: '🌸'),
  RasMissionChip(id: 'kindness',    label: 'مهربانی',          emoji: '💗'),
  RasMissionChip(id: 'growth',      label: 'رشد',              emoji: '🌱'),
  RasMissionChip(id: 'signs',       label: 'نشانه‌های کوچیک',  emoji: '🌀'),
];

/// کارت مأموریت ذهن — خالی (انتخاب چیپ) یا فعال (آمار + heatmap + feed)
class RasMission extends StatelessWidget {
  const RasMission({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BeliefsStore>();
    final mission = store.rasMission;

    if (mission == null) {
      return _EmptyState(store: store);
    }
    return _ActiveState(store: store, mission: mission);
  }
}

// ═══════════ حالت خالی ═══════════
class _EmptyState extends StatefulWidget {
  final BeliefsStore store;
  const _EmptyState({required this.store});
  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  String? _selectedChip;
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool get _canStart => _selectedChip != null || _customCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kEmerald500.withValues(alpha: 0.06),
            const Color(0xFF5EC8F0).withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kEmerald500.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Text('👁️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          const Text(
            'امروز می‌خوای چه چیزی رو بیشتر ببینی؟',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kInk),
          ),
          const SizedBox(height: 6),
          const Text(
            'ذهن تو هر لحظه داره فیلتر می‌کنه. اگه بدونی دنبال چی می‌گردی، همون چیز یهو «همه‌جا» ظاهر می‌شه.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: _kMuted, height: 1.7),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: kRasMissions.map((m) {
              final sel = _selectedChip == m.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedChip = sel ? null : m.id;
                    if (_selectedChip != null) _customCtrl.clear();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _kEmerald500 : _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? _kEmerald500 : _kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.emoji, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        m.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : _kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customCtrl,
            onChanged: (_) => setState(() {}),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 12, color: _kInk),
            decoration: InputDecoration(
              hintText: 'یا خودت بنویس: چیزی که می‌خوام ببینم...',
              hintStyle: const TextStyle(fontSize: 11.5, color: _kMuted),
              filled: true,
              fillColor: _kCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kEmerald500, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kEmerald500,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _kEmerald500.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _canStart
                  ? () {
                      final label = _customCtrl.text.trim().isNotEmpty
                          ? _customCtrl.text.trim()
                          : kRasMissions.firstWhere((m) => m.id == _selectedChip).label;
                      widget.store.startRasMission(
                        chipId: _selectedChip,
                        label: label,
                      );
                    }
                  : null,
              child: const Text('🚀 شروع مأموریت',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════ حالت فعال ═══════════
class _ActiveState extends StatelessWidget {
  final BeliefsStore store;
  final RasMissionData mission;

  const _ActiveState({required this.store, required this.mission});

  @override
  Widget build(BuildContext context) {
    final day = store.rasMissionDay;
    final todayCount = store.rasSignalsForDay(BeliefsStore.todayKey()).length;
    final weekDays = store.rasSignalsForLast7Days();
    final weekCount = weekDays.fold<int>(0, (s, d) => s + d.count);
    final totalCount = store.rasSignals.length;
    final feed = store.rasSignals.reversed.take(3).toList();
    final todayKey = BeliefsStore.todayKey();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kEmerald500.withValues(alpha: 0.08),
            _kGold500.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kEmerald500.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ ${mission.label}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'روز ${_toFa(day)} • از ${mission.startDate}',
                      style: const TextStyle(fontSize: 10.5, color: _kMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: _kMuted),
                tooltip: 'تغییر مأموریت',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: _kCard,
                      content: const Text('مأموریت فعلی رو تموم کنی و یکی جدید انتخاب کنی؟',
                          style: TextStyle(color: _kInk, fontSize: 13)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نه')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _kEmerald500),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('بله'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) store.endRasMission();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Record button
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kEmerald500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _openRecordSheet(context, store),
              icon: const Text('✋', style: TextStyle(fontSize: 16)),
              label: Text(
                todayCount == 0 ? 'امروز چیزی دیدی؟ ثبت کن' : 'ثبت نشانه‌ی جدید',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stats
          Row(
            children: [
              _stat(toFa(todayCount), 'امروز'),
              const SizedBox(width: 6),
              _stat(toFa(weekCount), 'این هفته'),
              const SizedBox(width: 6),
              _stat(toFa(totalCount), 'کل'),
            ],
          ),
          const SizedBox(height: 14),

          // Heatmap
          const Row(
            children: [
              Text('📊 پیشرفت هفته',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kInk)),
              Spacer(),
              Text('هفته‌ی اخیر',
                  style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: weekDays.map((d) {
              final lvl = d.count == 0 ? 0 : (d.count <= 2 ? 1 : (d.count <= 4 ? 2 : 3));
              final isToday = d.key == todayKey;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: lvl == 0
                            ? _kCream
                            : (lvl == 1
                                ? _kEmerald500.withValues(alpha: 0.25)
                                : (lvl == 2
                                    ? _kEmerald500.withValues(alpha: 0.5)
                                    : _kEmerald500)),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: _kGold500, width: 1.5)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        d.count > 0 ? toFa(d.count) : '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: lvl >= 2 ? Colors.white : _kEmerald700,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Feed
          Row(
            children: [
              const Text('📖 آخرین نشانه‌ها',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kInk)),
              const Spacer(),
              Text('${toFa(feed.length)} از ${toFa(totalCount)}',
                  style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          if (feed.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kCream,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'امروز هنوز چیزی ندیدی؟\nچشم‌هات رو باز کن 👀',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _kMuted, height: 1.7),
              ),
            )
          else
            ...feed.map((s) => _feedItem(context, store, s)),
        ],
      ),
    );
  }

  Widget _stat(String num, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          children: [
            Text(num,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _kEmerald700)),
            Text(label,
                style: const TextStyle(
                  fontSize: 9.5, color: _kMuted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _feedItem(BuildContext context, BeliefsStore store, RasSignal s) {
    final timeStr = '${s.ts.hour.toString().padLeft(2, '0')}:${s.ts.minute.toString().padLeft(2, '0')}';
    final dateStr = s.ts.year == DateTime.now().year &&
            s.ts.month == DateTime.now().month &&
            s.ts.day == DateTime.now().day
        ? 'امروز'
        : '${s.ts.year}/${s.ts.month}/${s.ts.day}';
    final feel = _feelMeta(s.feel);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('🌀 $dateStr $timeStr',
                      style: const TextStyle(
                        fontSize: 10.5, color: _kMuted, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: feel.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${feel.emoji} ${feel.label}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: feel.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                  s.text,
                  style: const TextStyle(fontSize: 12, color: _kInk, height: 1.7),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            child: GestureDetector(
              onTap: () => store.removeRasSignal(s.id),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: _kMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feel {
  final String label;
  final String emoji;
  final Color color;
  final Color textColor;
  const _Feel(this.label, this.emoji, this.color, this.textColor);
}

_Feel _feelMeta(String id) {
  switch (id) {
    case 'calm':   return const _Feel('آروم', '😌', Color(0xFF5EC8F0), Color(0xFF1D7BA0));
    case 'bright': return const _Feel('روشن', '✨', Color(0xFFF4C542), Color(0xFF8A6B00));
    case 'strong': return const _Feel('قوی', '🔥', Color(0xFF2BBFAB), Color(0xFF0F5B53));
    default:       return const _Feel('معمولی', '🙂', Color(0xFF78788C), Color(0xFF5A5A6A));
  }
}

void _openRecordSheet(BuildContext context, BeliefsStore store) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RecordSheet(store: store),
  );
}

class _RecordSheet extends StatefulWidget {
  final BeliefsStore store;
  const _RecordSheet({required this.store});
  @override
  State<_RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<_RecordSheet> {
  final _ctrl = TextEditingController();
  String _feel = 'normal';

  static const _feels = [
    {'id': 'normal', 'label': 'معمولی', 'emoji': '🙂'},
    {'id': 'calm',   'label': 'آروم',   'emoji': '😌'},
    {'id': 'bright', 'label': 'روشن',   'emoji': '✨'},
    {'id': 'strong', 'label': 'قوی',    'emoji': '🔥'},
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 14,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                '✋ چی دیدی؟',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                maxLines: 3,
                minLines: 2,
                style: const TextStyle(fontSize: 13, color: _kInk, height: 1.75),
                decoration: InputDecoration(
                  hintText: 'مثلاً: یه لبخند از یه غریبه توی صف نون...',
                  hintStyle: const TextStyle(fontSize: 12, color: _kMuted),
                  filled: true,
                  fillColor: _kCard,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kEmerald500, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('حست چی بود؟',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 8),
              Row(
                children: _feels.map((f) {
                  final sel = _feel == f['id'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => _feel = f['id']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? _kEmerald500 : _kCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: sel ? _kEmerald500 : _kBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(f['emoji']!, style: const TextStyle(fontSize: 18)),
                              const SizedBox(height: 3),
                              Text(
                                f['label']!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: sel ? Colors.white : _kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kMuted,
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('لغو'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kEmerald500,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _kEmerald500.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _ctrl.text.trim().isEmpty
                          ? null
                          : () {
                              widget.store.addRasSignal(_ctrl.text.trim(), _feel);
                              Navigator.pop(context);
                            },
                      child: const Text('ذخیره', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String toFa(int n) => n.toString().replaceAllMapped(
      RegExp(r'\d'),
      (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m.group(0)!)],
    );

String _toFa(int n) => toFa(n);
