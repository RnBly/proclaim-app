import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/bible_reading.dart';

class BibleService {
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  Map<String, dynamic>? _bibleData;
  List<BibleReading>? _oldTestamentData;
  List<BibleReading>? _psalmsData;
  List<BibleReading>? _newTestamentData;

  Future<void> initialize() async {
    await _loadBibleJson();
    await _loadExcel();
  }

  Future<void> _loadBibleJson() async {
    final String jsonString = await rootBundle.loadString('assets/bible.json');
    _bibleData = json.decode(jsonString);
  }

  Future<void> _loadExcel() async {
    final ByteData data = await rootBundle.load('assets/Proclaim.xlsx');
    final bytes = data.buffer.asUint8List();
    final excel = Excel.decodeBytes(bytes);

    _oldTestamentData = _parseSheet(excel, 'Old Testament');
    _psalmsData = _parseSheet(excel, 'Psalms');
    _newTestamentData = _parseSheet(excel, 'New Testament');
  }

  List<BibleReading> _parseSheet(Excel excel, String sheetName) {
    final sheet = excel.tables[sheetName];
    if (sheet == null) return [];

    final List<BibleReading> readings = [];

    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      try {
        final map = {
          'Date': row[0]?.value.toString() ?? '',
          'Book': row[1]?.value.toString() ?? '',
          'Book(ENG)': row[2]?.value.toString() ?? '',
          'Start Chapter': int.tryParse(row[3]?.value.toString() ?? '0') ?? 0,
          'End Chapter': int.tryParse(row[4]?.value.toString() ?? '0') ?? 0,
          'Full Name': row[5]?.value.toString() ?? '',
          'Full Name(ENG)': row[6]?.value.toString() ?? '',
        };
        readings.add(BibleReading.fromMap(map));
      } catch (e) {
        print('Error parsing row $i: $e');
      }
    }

    return readings;
  }

  BibleReading? getTodayReading(String sheetType) {
    final now = DateTime.now();
    return getReadingForDate(now, sheetType);
  }

  BibleReading? getReadingForDate(DateTime date, String sheetType) {
    final monthDay = DateFormat('MM-dd').format(date);

    List<BibleReading>? data;
    switch (sheetType) {
      case 'old':
        data = _oldTestamentData;
        break;
      case 'psalms':
        data = _psalmsData;
        break;
      case 'new':
        data = _newTestamentData;
        break;
    }

    return data?.firstWhere(
          (reading) => reading.date.contains(monthDay),
      orElse: () => data!.first,
    );
  }

  List<Verse> getVerses(String book, int startChapter, int endChapter) {
    final List<Verse> verses = [];

    if (_bibleData == null || _bibleData![book] == null) return verses;

    final bookData = _bibleData![book] as Map<String, dynamic>;

    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      final chapterKey = chapter.toString();
      if (bookData[chapterKey] == null) continue;

      final chapterData = bookData[chapterKey] as Map<String, dynamic>;

      chapterData.forEach((verseKey, verseText) {
        verses.add(Verse(
          book: book,
          chapter: chapter,
          verseNumber: int.parse(verseKey),
          text: verseText.toString(),
        ));
      });
    }

    return verses;
  }

  String formatSelectedVerses(List<SelectedVerse> verses) {
    if (verses.isEmpty) return '';

    verses.sort((a, b) {
      final bookOrder = ['창', '출', '레', '민', '신', '시', '마', '막', '눅', '요'];
      final aIndex = bookOrder.indexOf(a.book);
      final bIndex = bookOrder.indexOf(b.book);

      if (aIndex != bIndex) return aIndex.compareTo(bIndex);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verseNumber.compareTo(b.verseNumber);
    });

    final StringBuffer buffer = StringBuffer();
    String? lastBook;
    int? lastChapter;
    int? rangeStart;
    int? rangeEnd;
    List<SelectedVerse> currentRange = [];

    void writeRange() {
      if (currentRange.isEmpty) return;

      final first = currentRange.first;
      final last = currentRange.last;

      if (currentRange.length == 1) {
        buffer.writeln('[${first.book} ${first.chapter}:${first.verseNumber}]');
        buffer.writeln('${first.verseNumber}. ${first.text}');
      } else {
        buffer.writeln(
            '[${first.book} ${first.chapter}:${first.verseNumber}-${last.verseNumber}]');
        for (var verse in currentRange) {
          buffer.writeln('${verse.verseNumber}. ${verse.text}');
        }
      }
      buffer.writeln();
    }

    for (var verse in verses) {
      if (lastBook != verse.book || lastChapter != verse.chapter) {
        writeRange();
        currentRange = [verse];
        lastBook = verse.book;
        lastChapter = verse.chapter;
        rangeStart = verse.verseNumber;
        rangeEnd = verse.verseNumber;
      } else if (rangeEnd != null && verse.verseNumber == rangeEnd + 1) {
        currentRange.add(verse);
        rangeEnd = verse.verseNumber;
      } else {
        writeRange();
        currentRange = [verse];
        rangeStart = verse.verseNumber;
        rangeEnd = verse.verseNumber;
      }
    }

    writeRange();

    return buffer.toString().trim();
  }
}