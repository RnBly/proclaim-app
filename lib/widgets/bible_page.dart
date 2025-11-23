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
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reading = BibleService().getReadingForDate(widget.selectedDate, widget.sheetType);

    if (reading == null) {
      return const Center(child: Text('데이터를 불러올 수 없습니다'));
    }

    return Stack(
      children: [
        // 메인 콘텐츠
        if (widget.translation == Translation.korean)
          _buildKoreanView(reading)
        else if (widget.translation == Translation.esv)
          _buildEsvView(reading)
        else
          _buildCompareView(reading),

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
          final maxTop = constraints.maxHeight - indicatorHeight;
          final currentTop = maxTop * _scrollProgress;

          return Stack(
            children: [
              Positioned(
                top: currentTop,
                child: Container(
                  width: 3,
                  height: indicatorHeight,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
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

  Widget _buildKoreanView(BibleReading reading) {
    final verses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
      verseRange: reading.verseRange,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _getItemCount(verses),
      itemBuilder: (context, index) {
        return _buildItem(context, index, verses, reading);
      },
    );
  }

  Widget _buildEsvView(BibleReading reading) {
    final verses = BibleService().getEsvVerses(
      reading.bookEng,
      reading.startChapter,
      reading.endChapter,
      verseRange: reading.verseRange,
    );

    final koreanVerses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
      verseRange: reading.verseRange,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _getItemCount(verses),
      itemBuilder: (context, index) {
        return _buildItemEsv(context, index, verses, koreanVerses, reading);
      },
    );
  }

  Widget _buildCompareView(BibleReading reading) {
    final koreanVerses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
      verseRange: reading.verseRange,
    );

    final esvVerses = BibleService().getEsvVerses(
      reading.bookEng,
      reading.startChapter,
      reading.endChapter,
      verseRange: reading.verseRange,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _getCompareItemCount(koreanVerses),
      itemBuilder: (context, index) {
        return _buildCompareItem(context, index, koreanVerses, esvVerses, reading);
      },
    );
  }

  int _getItemCount(List<Verse> verses) {
    int count = 0;
    int? lastChapter;

    for (var verse in verses) {
      if (lastChapter != verse.chapter) {
        count++;
        lastChapter = verse.chapter;
      }
      count++;
    }

    return count;
  }

  int _getCompareItemCount(List<Verse> verses) {
    int count = 0;
    int? lastChapter;

    for (var verse in verses) {
      if (lastChapter != verse.chapter) {
        count++;
        lastChapter = verse.chapter;
      }
      count++;
    }

    return count;
  }

  Widget _buildItem(BuildContext context, int index, List<Verse> verses, BibleReading reading) {
    int currentIndex = 0;
    int? lastChapter;

    for (var verse in verses) {
      if (lastChapter != verse.chapter) {
        if (currentIndex == index) {
          lastChapter = verse.chapter;
          return _buildChapterHeader(reading.fullName, verse.chapter, false);
        }
        currentIndex++;
        lastChapter = verse.chapter;
      }

      if (currentIndex == index) {
        return _buildVerseItem(verse, verse.key);
      }
      currentIndex++;
    }

    return const SizedBox.shrink();
  }

  Widget _buildItemEsv(BuildContext context, int index, List<Verse> esvVerses, List<Verse> koreanVerses, BibleReading reading) {
    int currentIndex = 0;
    int? lastChapter;

    for (int i = 0; i < esvVerses.length; i++) {
      final esvVerse = esvVerses[i];

      if (lastChapter != esvVerse.chapter) {
        if (currentIndex == index) {
          lastChapter = esvVerse.chapter;
          return _buildChapterHeader(reading.fullNameEng, esvVerse.chapter, true);
        }
        currentIndex++;
        lastChapter = esvVerse.chapter;
      }

      if (currentIndex == index) {
        final koreanVerse = koreanVerses.firstWhere(
              (v) => v.chapter == esvVerse.chapter && v.verseNumber == esvVerse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );
        return _buildVerseItem(esvVerse, koreanVerse.key);
      }
      currentIndex++;
    }

    return const SizedBox.shrink();
  }

  Widget _buildCompareItem(BuildContext context, int index, List<Verse> koreanVerses, List<Verse> esvVerses, BibleReading reading) {
    int currentIndex = 0;
    int? lastChapter;

    for (int i = 0; i < koreanVerses.length; i++) {
      final koreanVerse = koreanVerses[i];

      if (lastChapter != koreanVerse.chapter) {
        if (currentIndex == index) {
          lastChapter = koreanVerse.chapter;
          return _buildCompareChapterHeader(
            reading.fullName,
            reading.fullNameEng,
            koreanVerse.chapter,
          );
        }
        currentIndex++;
        lastChapter = koreanVerse.chapter;
      }

      if (currentIndex == index) {
        final esvVerse = esvVerses.firstWhere(
              (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );
        return _buildCompareVerseItem(koreanVerse, esvVerse);
      }
      currentIndex++;
    }

    return const SizedBox.shrink();
  }

  Widget _buildChapterHeader(String fullName, int chapter, bool isEsv) {
    final isPsalms = fullName.contains('시편') || fullName.toLowerCase().contains('psalm');
    final chapterLabel = isPsalms ? '편' : '장';

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        isEsv
            ? '$fullName $chapter (ESV)'
            : isPsalms
            ? '시편 $chapter$chapterLabel(개역개정)'
            : '$fullName $chapter$chapterLabel(개역개정)',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: widget.titleFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCompareChapterHeader(String koreanName, String englishName, int chapter) {
    final isPsalms = koreanName.contains('시편') || englishName.toLowerCase().contains('psalm');
    final chapterLabel = isPsalms ? '편' : '장';

    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          Text(
            isPsalms
                ? '시편 $chapter$chapterLabel(개역개정)'
                : '$koreanName $chapter$chapterLabel(개역개정)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$englishName $chapter (ESV)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: widget.titleFontSize * 0.8,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseItem(Verse verse, String keyToUse) {
    final isSelected = widget.selectedVerses.contains(keyToUse);

    // 하이라이트 색상 확인
    final highlightKey = '${verse.book}-${verse.chapter}-${verse.verseNumber}';
    final highlightColorName = widget.highlightedVerses[highlightKey];
    final highlightColor = highlightColorName != null
        ? MeditationColors.getColor(highlightColorName)
        : null;
    final isHighlighted = highlightColor != null;

    return GestureDetector(
      onTap: () => widget.onVerseToggle(keyToUse),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.15)
              : isHighlighted
              ? highlightColor.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: widget.bodyFontSize,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                  children: [
                    TextSpan(
                      text: '${verse.verseNumber}. ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    TextSpan(text: verse.text),
                  ],
                ),
              ),
            ),
            // 하이라이트된 구절이면 묵상 보기 아이콘 표시
            if (isHighlighted && widget.onMeditationView != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => widget.onMeditationView?.call(
                    verse.book,
                    verse.chapter,
                    verse.verseNumber,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCE6E26).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '📄',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFCE6E26),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareVerseItem(Verse koreanVerse, Verse esvVerse) {
    final isSelected = widget.selectedVerses.contains(koreanVerse.key);

    // 하이라이트 색상 확인
    final highlightKey = '${koreanVerse.book}-${koreanVerse.chapter}-${koreanVerse.verseNumber}';
    final highlightColorName = widget.highlightedVerses[highlightKey];
    final highlightColor = highlightColorName != null
        ? MeditationColors.getColor(highlightColorName)
        : null;
    final isHighlighted = highlightColor != null;

    return GestureDetector(
      onTap: () => widget.onVerseToggle(koreanVerse.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.15)
              : isHighlighted
              ? highlightColor.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: widget.bodyFontSize,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                      children: [
                        TextSpan(
                          text: '${koreanVerse.verseNumber}. ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        TextSpan(text: koreanVerse.text),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: widget.bodyFontSize,
                        height: 1.6,
                        color: Colors.black54,
                      ),
                      children: [
                        TextSpan(
                          text: '${esvVerse.verseNumber}. ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                        TextSpan(text: esvVerse.text),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 하이라이트된 구절이면 묵상 보기 아이콘 표시
            if (isHighlighted && widget.onMeditationView != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: InkWell(
                  onTap: () => widget.onMeditationView?.call(
                    koreanVerse.book,
                    koreanVerse.chapter,
                    koreanVerse.verseNumber,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCE6E26).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '📄',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFCE6E26),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}