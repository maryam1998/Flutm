// lib/screens/shenakht/search_screen.dart
import 'package:flutter/material.dart';

import '../../data/shenakht/schemas.dart';
import '../../data/shenakht/simple_language.dart';
import 'shenakht_tab.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String schemaId) onPickSchema;

  const SearchScreen({
    super.key,
    required this.onBack,
    required this.onPickSchema,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Schema> get _results {
    if (_query.trim().isEmpty) return const [];
    final q = _query.toLowerCase().trim();
    return schemas.where((s) {
      final plain = getPlainName(s.id) ?? '';
      final one = getOneLiner(s.id) ?? '';
      return s.nameFa.contains(q) ||
          s.nameEn.toLowerCase().contains(q) ||
          plain.contains(q) ||
          one.contains(q) ||
          s.shortDescription.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;

    return ShenakhtShell(
      title: 'جستجو',
      onBack: widget.onBack,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'جستجو در الگوها...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _query.trim().isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'چند حرف تایپ کن تا نتایج نشون داده بشه.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF999999)),
                      ),
                    ),
                  )
                : results.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'چیزی پیدا نشد. یک عبارت دیگه امتحان کن.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF999999)),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final s = results[i];
                          final plain =
                              getPlainName(s.id) ?? s.nameFa;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () =>
                                    widget.onPickSchema(s.id),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFF0F0F0)),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Text('🧩',
                                          style:
                                              TextStyle(fontSize: 18)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(plain,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(s.nameFa,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(
                                                        0xFF999999))),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                          Icons.arrow_back,
                                          size: 16,
                                          color: Color(0xFFCCCCCC)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
