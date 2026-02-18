/**
 * bible_page.dart
 * 
 * 성경 본문을 표시하는 페이지
 * 
 * 주요 기능:
 * - 한글/영어/비교 모드 지원
 * - 절 선택 기능 (탭하여 선택/해제)
 * - 선택된 절 복사 (CopyDialog)
 * - 묵상 작성 (MeditationWritingDialog)
 * - 폰트 크기 조절 (설정에서)
 * - 구절 하이라이트 (묵상이 있는 경우)
 * 
 * UI 구성:
 * - AppBar: 제목, 역본 전환 버튼
 * - Body: 성경 본문 (ScrollView)
 * - BottomSheet: 선택된 절이 있을 때 표시
 */

import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../models/bible_reading.dart';
import 'translation_dialog.dart';
import '../config/meditation_colors.dart';

class BiblePage extends StatefulWidget {
  final String sheetType;
  final DateTime selectedDate;
  final Translation translation;
  final Set<String> selectedVerses;
  final Map<String, String> highlightedVerses;
  final Function(String) onVerseToggle;
  final Function(String, int, int)? onMeditationView;
  final double titleFontSize;
  final double bodyFontSize;
  final Function(double)? onScrollProgressChanged;

  const BiblePage({
    super.key,
    required this.sheetType,
    required this.selectedDate,
    required this.translation,
    required this.selectedVerses,
    required this.highlightedVerses,
    required this.onVerseToggle,
    this.onMeditationView,
    required this.titleFontSize,
    required this.bodyFontSize,
    this.onScrollProgressChanged,
  });

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final progress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      setState(() {
        _scrollProgress = progress;
      });
      widget.onScrollProgressChanged?.call(progress);
    }
  }

  // 시편인지 확인하는 헬퍼 함수
  bool _isPsalm(String bookName) {
    return bookName == '시' || bookName == 'Ps';
  }

  // 장/편 표시 텍스트 생성
  String _getChapterText(String bookName, int chapter, {bool isEnglish = false}) {
    if (_isPsalm(bookName)) {
      return isEnglish ? 'Chapter $chapter' : '$chapter편';
    }
    return isEnglish ? 'Chapter $chapter' : '$chapter장';
  }

  @override
  Widget build(BuildContext context) {
    // 같은 날짜의 모든 읽기 계획 가져오기
    final readings = BibleService().getAllReadingsForDate(widget.selectedDate, widget.sheetType);

    if (readings.isEmpty) {
      return const Center(child: Text('데이터를 불러올 수 없습니다'));
    }

    return Stack(
      children: [
        // 메인 콘텐츠
        if (widget.translation == Translation.korean)
          _buildKoreanView(readings)
        else if (widget.translation == Translation.esv)
          _buildEsvView(readings)
        else
          _buildCompareView(readings),

        // 스크롤 진행도 표시 (오른쪽)
        Positioned(
          right: 4,
          top: 20,
          bottom: 20,
          child: _buildScrollIndicator(),
        ),
      ],
    );
  }

  Widget _buildScrollIndicator() {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final indicatorHeight = constraints.maxHeight * 0.1;
          final maxOffset = constraints.maxHeight - indicatorHeight;
          final currentOffset = maxOffset * _scrollProgress;

          return Stack(
            children: [
              Positioned(
                top: currentOffset,
                child: Container(
                  width: 3,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKoreanView(List<BibleReading> readings) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // 각 읽기 계획에 대해 콘텐츠 생성
        for (var reading in readings) ...[
          // 각 장별로 분리하여 표시
          for (int chapter = reading.startChapter; chapter <= reading.endChapter; chapter++) ...[
            // 책 제목 + 장/편
            Padding(
              padding: EdgeInsets.only(
                bottom: 20,
                top: chapter == reading.startChapter ? 0 : 30,
              ),
              child: Text(
                '${reading.fullName} ${_getChapterText(reading.book, chapter)}',
                style: TextStyle(
                  fontSize: widget.titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 해당 장의 구절들
            ..._buildChapterVerses(reading, chapter),
          ],

          // 읽기 계획이 여러 개인 경우 구분선 추가
          if (readings.length > 1 && reading != readings.last)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 2,
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _buildChapterVerses(BibleReading reading, int chapter) {
    final verses = BibleService().getVerses(
      reading.book,
      chapter,
      chapter,
      verseRange: reading.verseRange,
    );

    return verses.map((verse) {
      final key = verse.key;
      final isSelected = widget.selectedVerses.contains(key);
      final highlightKey = '${verse.book}-${verse.chapter}-${verse.verseNumber}';
      final highlightColor = widget.highlightedVerses[highlightKey];

      return GestureDetector(
        onTap: () => widget.onVerseToggle(key),
        onLongPress: highlightColor != null
            ? () => widget.onMeditationView?.call(verse.book, verse.chapter, verse.verseNumber)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withOpacity(0.1)
                : (highlightColor != null
                ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : (highlightColor != null
                  ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                  : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 구절 텍스트
              Padding(
                padding: highlightColor != null
                    ? const EdgeInsets.only(right: 30)
                    : EdgeInsets.zero,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.verseNumber}. ',
                        style: TextStyle(
                          fontSize: widget.bodyFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      TextSpan(
                        text: verse.text,
                        style: TextStyle(
                          fontSize: widget.bodyFontSize,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 묵상 아이콘 (하이라이트된 구절에만 표시)
              if (highlightColor != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => widget.onMeditationView?.call(verse.book, verse.chapter, verse.verseNumber),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📄',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildEsvView(List<BibleReading> readings) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // 각 읽기 계획에 대해 콘텐츠 생성
        for (var reading in readings) ...[
          // 각 장별로 분리하여 표시
          for (int chapter = reading.startChapter; chapter <= reading.endChapter; chapter++) ...[
            // 책 제목 + Chapter
            Padding(
              padding: EdgeInsets.only(
                bottom: 20,
                top: chapter == reading.startChapter ? 0 : 30,
              ),
              child: Text(
                '${reading.fullNameEng} ${_getChapterText(reading.bookEng, chapter, isEnglish: true)}',
                style: TextStyle(
                  fontSize: widget.titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 해당 장의 구절들
            ..._buildEsvChapterVerses(reading, chapter),
          ],

          // 읽기 계획이 여러 개인 경우 구분선 추가
          if (readings.length > 1 && reading != readings.last)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 2,
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _buildEsvChapterVerses(BibleReading reading, int chapter) {
    final verses = BibleService().getEsvVerses(
      reading.bookEng,
      chapter,
      chapter,
      verseRange: reading.verseRange,
    );

    final koreanVerses = BibleService().getVerses(
      reading.book,
      chapter,
      chapter,
      verseRange: reading.verseRange,
    );

    return verses.map((verse) {
      final koreanVerse = koreanVerses.firstWhere(
            (v) => v.chapter == verse.chapter && v.verseNumber == verse.verseNumber,
        orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
      );

      final key = koreanVerse.key;
      final isSelected = widget.selectedVerses.contains(key);
      final highlightKey = '${reading.book}-${verse.chapter}-${verse.verseNumber}';
      final highlightColor = widget.highlightedVerses[highlightKey];

      return GestureDetector(
        onTap: () => widget.onVerseToggle(key),
        onLongPress: highlightColor != null
            ? () => widget.onMeditationView?.call(reading.book, verse.chapter, verse.verseNumber)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withOpacity(0.1)
                : (highlightColor != null
                ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : (highlightColor != null
                  ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                  : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 구절 텍스트
              Padding(
                padding: highlightColor != null
                    ? const EdgeInsets.only(right: 30)
                    : EdgeInsets.zero,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.verseNumber}. ',
                        style: TextStyle(
                          fontSize: widget.bodyFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                      TextSpan(
                        text: verse.text,
                        style: TextStyle(
                          fontSize: widget.bodyFontSize,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 묵상 아이콘
              if (highlightColor != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => widget.onMeditationView?.call(reading.book, verse.chapter, verse.verseNumber),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📄',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildCompareView(List<BibleReading> readings) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        // 각 읽기 계획에 대해 콘텐츠 생성
        for (var reading in readings) ...[
          // 각 장별로 분리하여 표시
          for (int chapter = reading.startChapter; chapter <= reading.endChapter; chapter++) ...[
            // 책 제목 (한글 + 영문)
            Padding(
              padding: EdgeInsets.only(
                bottom: 8,
                top: chapter == reading.startChapter ? 0 : 30,
              ),
              child: Text(
                '${reading.fullName} ${_getChapterText(reading.book, chapter)}',
                style: TextStyle(
                  fontSize: widget.titleFontSize,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                '${reading.fullNameEng} ${_getChapterText(reading.bookEng, chapter, isEnglish: true)}',
                style: TextStyle(
                  fontSize: widget.titleFontSize - 2,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // 해당 장의 구절들
            ..._buildCompareChapterVerses(reading, chapter),
          ],

          // 읽기 계획이 여러 개인 경우 구분선 추가
          if (readings.length > 1 && reading != readings.last)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Divider(
                color: Colors.grey.shade300,
                thickness: 2,
              ),
            ),
        ],
      ],
    );
  }

  List<Widget> _buildCompareChapterVerses(BibleReading reading, int chapter) {
    final koreanVerses = BibleService().getVerses(
      reading.book,
      chapter,
      chapter,
      verseRange: reading.verseRange,
    );

    final esvVerses = BibleService().getEsvVerses(
      reading.bookEng,
      chapter,
      chapter,
      verseRange: reading.verseRange,
    );

    return koreanVerses.map((koreanVerse) {
      final esvVerse = esvVerses.firstWhere(
            (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
        orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
      );

      final key = koreanVerse.key;
      final isSelected = widget.selectedVerses.contains(key);
      final highlightKey = '${koreanVerse.book}-${koreanVerse.chapter}-${koreanVerse.verseNumber}';
      final highlightColor = widget.highlightedVerses[highlightKey];

      return GestureDetector(
        onTap: () => widget.onVerseToggle(key),
        onLongPress: highlightColor != null
            ? () => widget.onMeditationView?.call(koreanVerse.book, koreanVerse.chapter, koreanVerse.verseNumber)
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.blue.withOpacity(0.1)
                : (highlightColor != null
                ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.blue
                  : (highlightColor != null
                  ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                  : Colors.transparent),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              // 구절 내용
              Padding(
                padding: highlightColor != null
                    ? const EdgeInsets.only(right: 30)
                    : EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 한글 구절
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${koreanVerse.verseNumber}. ',
                            style: TextStyle(
                              fontSize: widget.bodyFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade600,
                            ),
                          ),
                          TextSpan(
                            text: koreanVerse.text,
                            style: TextStyle(
                              fontSize: widget.bodyFontSize,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (esvVerse.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      // const Divider(height: ),
                      const SizedBox(height: 2),
                      // 영문 구절
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${esvVerse.verseNumber}. ',
                              style: TextStyle(
                                fontSize: widget.bodyFontSize - 2,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            TextSpan(
                              text: esvVerse.text,
                              style: TextStyle(
                                fontSize: widget.bodyFontSize - 1,
                                height: 1.4,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 묵상 아이콘
              if (highlightColor != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => widget.onMeditationView?.call(koreanVerse.book, koreanVerse.chapter, koreanVerse.verseNumber),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Text(
                        '📄',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }
}