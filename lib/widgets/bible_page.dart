import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../models/bible_reading.dart';
import 'translation_dialog.dart';

class BiblePage extends StatelessWidget {
  final String sheetType;
  final DateTime selectedDate;
  final Translation translation;
  final Set<String> selectedVerses;
  final Function(String) onVerseToggle;

  const BiblePage({
    super.key,
    required this.sheetType,
    required this.selectedDate,
    required this.translation,
    required this.selectedVerses,
    required this.onVerseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final reading = BibleService().getReadingForDate(selectedDate, sheetType);

    if (reading == null) {
      return const Center(child: Text('데이터를 불러올 수 없습니다'));
    }

    if (translation == Translation.korean) {
      return _buildKoreanView(reading);
    } else if (translation == Translation.esv) {
      return _buildEsvView(reading);
    } else {
      return _buildCompareView(reading);
    }
  }

  Widget _buildKoreanView(BibleReading reading) {
    final verses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
    );

    return ListView.builder(
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
    );

    final koreanVerses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
    );

    return ListView.builder(
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
    );

    final esvVerses = BibleService().getEsvVerses(
      reading.bookEng,
      reading.startChapter,
      reading.endChapter,
    );

    return ListView.builder(
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
        // ESV 절이지만 한글 key 사용
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
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        isEsv ? '$fullName $chapter (ESV)' : '$fullName ${chapter}장(개역개정)',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildCompareChapterHeader(String koreanName, String englishName, int chapter) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          Text(
            '$koreanName ${chapter}장(개역개정)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$englishName $chapter (ESV)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseItem(Verse verse, String keyToUse) {
    final isSelected = selectedVerses.contains(keyToUse);

    return GestureDetector(
      onTap: () => onVerseToggle(keyToUse),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
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
    );
  }

  Widget _buildCompareVerseItem(Verse koreanVerse, Verse esvVerse) {
    final isSelected = selectedVerses.contains(koreanVerse.key);

    return GestureDetector(
      onTap: () => onVerseToggle(koreanVerse.key),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 16,
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
                style: const TextStyle(
                  fontSize: 14,
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
    );
  }
}