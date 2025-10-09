import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import '../models/bible_reading.dart';

class BiblePage extends StatelessWidget {
  final String sheetType;
  final DateTime selectedDate;
  final Set<String> selectedVerses;
  final Function(String) onVerseToggle;

  const BiblePage({
    super.key,
    required this.sheetType,
    required this.selectedDate,
    required this.selectedVerses,
    required this.onVerseToggle,
  });

  @override
  Widget build(BuildContext context) {
    final reading = BibleService().getReadingForDate(selectedDate, sheetType);

    if (reading == null) {
      return const Center(child: Text('데이터를 불러올 수 없습니다'));
    }

    final verses = BibleService().getVerses(
      reading.book,
      reading.startChapter,
      reading.endChapter,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _getItemCount(verses, reading),
      itemBuilder: (context, index) {
        return _buildItem(context, index, verses, reading);
      },
    );
  }

  int _getItemCount(List<Verse> verses, BibleReading reading) {
    int count = 0;
    int? lastChapter;

    for (var verse in verses) {
      if (lastChapter != verse.chapter) {
        count++; // 장 헤더
        lastChapter = verse.chapter;
      }
      count++; // 절
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
          return _buildChapterHeader(reading.fullName, verse.chapter);
        }
        currentIndex++;
        lastChapter = verse.chapter;
      }

      if (currentIndex == index) {
        return _buildVerseItem(verse);
      }
      currentIndex++;
    }

    return const SizedBox.shrink();
  }

  Widget _buildChapterHeader(String fullName, int chapter) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Text(
        '$fullName ${chapter}장(개역개정)',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildVerseItem(Verse verse) {
    final isSelected = selectedVerses.contains(verse.key);

    return GestureDetector(
      onTap: () => onVerseToggle(verse.key),
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
}