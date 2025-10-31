// lib/services/bible_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
// import 'package:csv/csv.dart';  ← 이 줄 삭제!
import '../models/bible_reading.dart';
import '../config/secrets.dart';

class BibleService {
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  Map<String, dynamic>? _bibleData;
  Map<String, dynamic>? _bibleEsvData;
  List<BibleReading>? _oldTestamentData;
  List<BibleReading>? _psalmsData;
  List<BibleReading>? _newTestamentData;

  Future<void> initialize() async {
    print('🚀 Initializing Bible Service...');

    try {
      await _loadReadingPlanFromGoogleSheets();
      print('✅ Loaded reading plan from Google Sheets');
    } catch (e) {
      print('⚠️ Google Sheets failed: $e');
      print('📦 Using local Excel...');
      await _loadExcelFromAssets();
    }

    try {
      await _loadBibleFromGitHub();
      print('✅ Loaded Bible data from GitHub');
    } catch (e) {
      print('⚠️ GitHub failed: $e');
      print('📦 Using local JSON...');
      await _loadBibleFromAssets();
    }
  }

  // ===== Google Sheets에서 직접 읽기 =====

  Future<void> _loadReadingPlanFromGoogleSheets() async {
    print('📊 Loading from Google Sheets...');

    final results = await Future.wait([
      _fetchSheetAsCsv(Secrets.OLD_TESTAMENT_SHEET),
      _fetchSheetAsCsv(Secrets.PSALMS_SHEET),
      _fetchSheetAsCsv(Secrets.NEW_TESTAMENT_SHEET),
    ]);

    _oldTestamentData = _parseCsvData(results[0]);
    _psalmsData = _parseCsvData(results[1]);
    _newTestamentData = _parseCsvData(results[2]);

    print('  ✓ Old Testament: ${_oldTestamentData?.length ?? 0} entries');
    print('  ✓ Psalms: ${_psalmsData?.length ?? 0} entries');
    print('  ✓ New Testament: ${_newTestamentData?.length ?? 0} entries');
  }

  Future<String> _fetchSheetAsCsv(String sheetName) async {
    final url = Secrets.getSheetCsvUrl(sheetName);
    print('  ⬇ Fetching $sheetName...');

    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      print('  ✓ Fetched $sheetName');
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('Failed to fetch $sheetName: ${response.statusCode}');
    }
  }

  // ===== CSV 파싱 (패키지 없이 직접 구현) =====

  List<BibleReading> _parseCsvData(String csvString) {
    final readings = <BibleReading>[];
    final lines = csvString.split('\n');

    // 첫 행은 헤더이므로 건너뛰기
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      try {
        // CSV 파싱 (간단한 구현)
        final row = _parseCsvLine(line);
        if (row.length < 7) continue;

        final map = {
          'Date': row[0],
          'Book': row[1],
          'Book(ENG)': row[2],
          'Start Chapter': int.tryParse(row[3]) ?? 0,
          'End Chapter': int.tryParse(row[4]) ?? 0,
          'Full Name': row[5],
          'Full Name(ENG)': row[6],
          'Verse': row.length > 7 ? row[7] : null,
        };
        readings.add(BibleReading.fromMap(map));
      } catch (e) {
        print('⚠️ Error parsing row $i: $e');
      }
    }

    return readings;
  }

  // CSV 라인 파싱 (따옴표 처리 포함)
  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    // 마지막 필드 추가
    result.add(buffer.toString().trim());

    return result;
  }

  // ===== GitHub에서 성경 데이터 로드 =====

  Future<void> _loadBibleFromGitHub() async {
    print('📥 Loading Bible data from GitHub...');

    final directory = await getApplicationDocumentsDirectory();
    final jsonPath = '${directory.path}/bible.json';
    final esvJsonPath = '${directory.path}/bible_esv.json';

    await _downloadFileWithCache(Secrets.BIBLE_JSON_URL, jsonPath, 'bible.json');
    await _downloadFileWithCache(Secrets.BIBLE_ESV_JSON_URL, esvJsonPath, 'bible_esv.json');

    final jsonString = await File(jsonPath).readAsString();
    _bibleData = json.decode(jsonString);

    final esvJsonString = await File(esvJsonPath).readAsString();
    _bibleEsvData = json.decode(esvJsonString);
    _cleanEsvQuotes();
  }

  Future<void> _downloadFileWithCache(String url, String savePath, String fileName) async {
    final file = File(savePath);

    if (await file.exists()) {
      final lastModified = await file.lastModified();
      final age = DateTime.now().difference(lastModified);

      if (age.inHours < 24) {
        print('  ✓ Using cached $fileName');
        return;
      }
    }

    print('  ⬇ Downloading $fileName...');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      final sizeKB = (response.bodyBytes.length / 1024).toStringAsFixed(1);
      print('  ✓ Downloaded $fileName ($sizeKB KB)');
    } else {
      throw Exception('Failed to download $fileName');
    }
  }

  // ===== Assets에서 로드 (백업) =====

  Future<void> _loadExcelFromAssets() async {
    final ByteData data = await rootBundle.load('assets/Proclaim.xlsx');
    final bytes = data.buffer.asUint8List();
    final excel = Excel.decodeBytes(bytes);

    _oldTestamentData = _parseSheet(excel, 'Old Testament');
    _psalmsData = _parseSheet(excel, 'Psalms');
    _newTestamentData = _parseSheet(excel, 'New Testament');
  }

  Future<void> _loadBibleFromAssets() async {
    final bibleJson = await rootBundle.loadString('assets/bible.json');
    _bibleData = json.decode(bibleJson);

    final esvJson = await rootBundle.loadString('assets/bible_esv.json');
    _bibleEsvData = json.decode(esvJson);
    _cleanEsvQuotes();
  }

  void _cleanEsvQuotes() {
    if (_bibleEsvData == null) return;

    _bibleEsvData!.forEach((book, chapters) {
      if (chapters is Map<String, dynamic>) {
        chapters.forEach((chapter, verses) {
          if (verses is Map<String, dynamic>) {
            verses.forEach((verseNum, verseText) {
              if (verseText is String) {
                verses[verseNum] = verseText.replaceAll(r'\"', '"');
              }
            });
          }
        });
      }
    });
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
          'Verse': row[7]?.value.toString(),
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

  List<Verse> getVerses(String book, int startChapter, int endChapter, {String? verseRange}) {
    print('getVerses called: book=$book, chapters=$startChapter-$endChapter, verseRange=$verseRange');

    final List<Verse> verses = [];

    if (_bibleData == null || _bibleData![book] == null) return verses;

    final bookData = _bibleData![book] as Map<String, dynamic>;

    int? startVerse;
    int? endVerse;
    if (verseRange != null && verseRange.contains('-')) {
      final parts = verseRange.split('-');
      startVerse = int.tryParse(parts[0].trim());
      endVerse = int.tryParse(parts[1].trim());
    }

    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      final chapterKey = chapter.toString();
      if (bookData[chapterKey] == null) continue;

      final chapterData = bookData[chapterKey] as Map<String, dynamic>;

      chapterData.forEach((verseKey, verseText) {
        try {
          if (verseKey.contains('-')) {
            final parts = verseKey.split('-');
            final verseStart = int.parse(parts[0].trim());
            final verseEnd = int.parse(parts[1].trim());

            if (startVerse != null && endVerse != null) {
              if (verseStart < startVerse || verseStart > endVerse) {
                return;
              }
            }

            verses.add(Verse(
              book: book,
              chapter: chapter,
              verseNumber: verseStart,
              text: verseText.toString(),
            ));

            for (int v = verseStart + 1; v <= verseEnd; v++) {
              if (startVerse != null && endVerse != null) {
                if (v < startVerse || v > endVerse) continue;
              }
              verses.add(Verse(
                book: book,
                chapter: chapter,
                verseNumber: v,
                text: '($verseStart절에 포함)',
              ));
            }
          } else {
            final verseNum = int.parse(verseKey);

            if (startVerse != null && endVerse != null) {
              if (verseNum < startVerse || verseNum > endVerse) {
                return;
              }
            }

            verses.add(Verse(
              book: book,
              chapter: chapter,
              verseNumber: verseNum,
              text: verseText.toString(),
            ));
          }
        } catch (e) {
          print('Error parsing verse $book $chapter:$verseKey - $e');
        }
      });
    }

    verses.sort((a, b) {
      if (a.chapter != b.chapter) {
        return a.chapter.compareTo(b.chapter);
      }
      return a.verseNumber.compareTo(b.verseNumber);
    });

    return verses;
  }

  List<Verse> getEsvVerses(String bookEng, int startChapter, int endChapter, {String? verseRange}) {
    final List<Verse> verses = [];

    if (_bibleEsvData == null || _bibleEsvData![bookEng] == null) return verses;

    final bookData = _bibleEsvData![bookEng] as Map<String, dynamic>;

    int? startVerse;
    int? endVerse;
    if (verseRange != null && verseRange.contains('-')) {
      final parts = verseRange.split('-');
      startVerse = int.tryParse(parts[0].trim());
      endVerse = int.tryParse(parts[1].trim());
    }

    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      final chapterKey = chapter.toString();
      if (bookData[chapterKey] == null) continue;

      final chapterData = bookData[chapterKey] as Map<String, dynamic>;

      chapterData.forEach((verseKey, verseText) {
        try {
          if (verseKey.contains('-')) {
            final parts = verseKey.split('-');
            final verseStart = int.parse(parts[0].trim());
            final verseEnd = int.parse(parts[1].trim());

            if (startVerse != null && endVerse != null) {
              if (verseStart < startVerse || verseStart > endVerse) {
                return;
              }
            }

            verses.add(Verse(
              book: bookEng,
              chapter: chapter,
              verseNumber: verseStart,
              text: verseText.toString(),
            ));

            for (int v = verseStart + 1; v <= verseEnd; v++) {
              if (startVerse != null && endVerse != null) {
                if (v < startVerse || v > endVerse) continue;
              }
              verses.add(Verse(
                book: bookEng,
                chapter: chapter,
                verseNumber: v,
                text: '(Included in verse $verseStart)',
              ));
            }
          } else {
            final verseNum = int.parse(verseKey);

            if (startVerse != null && endVerse != null) {
              if (verseNum < startVerse || verseNum > endVerse) {
                return;
              }
            }

            verses.add(Verse(
              book: bookEng,
              chapter: chapter,
              verseNumber: verseNum,
              text: verseText.toString(),
            ));
          }
        } catch (e) {
          print('Error parsing verse $bookEng $chapter:$verseKey - $e');
        }
      });
    }

    verses.sort((a, b) {
      if (a.chapter != b.chapter) {
        return a.chapter.compareTo(b.chapter);
      }
      return a.verseNumber.compareTo(b.verseNumber);
    });

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
        rangeEnd = verse.verseNumber;
      } else if (rangeEnd != null && verse.verseNumber == rangeEnd + 1) {
        currentRange.add(verse);
        rangeEnd = verse.verseNumber;
      } else {
        writeRange();
        currentRange = [verse];
        rangeEnd = verse.verseNumber;
      }
    }

    writeRange();

    return buffer.toString().trim();
  }

  String formatSelectedVersesEsv(List<SelectedVerseEsv> verses) {
    if (verses.isEmpty) return '';

    verses.sort((a, b) {
      final bookOrder = ['Gen', 'Exo', 'Lev', 'Num', 'Deu', 'Psa', 'Mat', 'Mar', 'Luk', 'Joh'];
      final aIndex = bookOrder.indexOf(a.bookEng);
      final bIndex = bookOrder.indexOf(b.bookEng);

      if (aIndex != bIndex) return aIndex.compareTo(bIndex);
      if (a.chapter != b.chapter) return a.chapter.compareTo(b.chapter);
      return a.verseNumber.compareTo(b.verseNumber);
    });

    final StringBuffer buffer = StringBuffer();
    String? lastBook;
    int? lastChapter;
    int? rangeEnd;
    List<SelectedVerseEsv> currentRange = [];

    void writeRange() {
      if (currentRange.isEmpty) return;

      final first = currentRange.first;
      final last = currentRange.last;

      if (currentRange.length == 1) {
        buffer.writeln('[${first.bookEng} ${first.chapter}:${first.verseNumber}]');
        buffer.writeln('${first.verseNumber}. ${first.text}');
      } else {
        buffer.writeln(
            '[${first.bookEng} ${first.chapter}:${first.verseNumber}-${last.verseNumber}]');
        for (var verse in currentRange) {
          buffer.writeln('${verse.verseNumber}. ${verse.text}');
        }
      }
      buffer.writeln();
    }

    for (var verse in verses) {
      if (lastBook != verse.bookEng || lastChapter != verse.chapter) {
        writeRange();
        currentRange = [verse];
        lastBook = verse.bookEng;
        lastChapter = verse.chapter;
        rangeEnd = verse.verseNumber;
      } else if (rangeEnd != null && verse.verseNumber == rangeEnd + 1) {
        currentRange.add(verse);
        rangeEnd = verse.verseNumber;
      } else {
        writeRange();
        currentRange = [verse];
        rangeEnd = verse.verseNumber;
      }
    }

    writeRange();

    return buffer.toString().trim();
  }

  String formatSelectedVersesCompare(List<SelectedVerseCompare> verses) {
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
    int? rangeEnd;
    List<SelectedVerseCompare> currentRange = [];

    void writeRange() {
      if (currentRange.isEmpty) return;

      final first = currentRange.first;
      final last = currentRange.last;

      if (currentRange.length == 1) {
        buffer.writeln('[${first.book} ${first.chapter}:${first.verseNumber}]');
        buffer.writeln('${first.verseNumber}. ${first.koreanText}');
        buffer.writeln('${first.verseNumber}. ${first.englishText}');
      } else {
        buffer.writeln('[${first.book} ${first.chapter}:${first.verseNumber}-${last.verseNumber}]');
        for (var verse in currentRange) {
          buffer.writeln('${verse.verseNumber}. ${verse.koreanText}');
          buffer.writeln('${verse.verseNumber}. ${verse.englishText}');
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
        rangeEnd = verse.verseNumber;
      } else if (rangeEnd != null && verse.verseNumber == rangeEnd + 1) {
        currentRange.add(verse);
        rangeEnd = verse.verseNumber;
      } else {
        writeRange();
        currentRange = [verse];
        rangeEnd = verse.verseNumber;
      }
    }

    writeRange();

    return buffer.toString().trim();
  }

  Future<void> forceRefresh() async {
    print('🔄 Force refreshing...');

    final directory = await getApplicationDocumentsDirectory();
    final jsonFile = File('${directory.path}/bible.json');
    final esvJsonFile = File('${directory.path}/bible_esv.json');

    if (await jsonFile.exists()) await jsonFile.delete();
    if (await esvJsonFile.exists()) await esvJsonFile.delete();

    await initialize();
    print('✅ Force refresh completed');
  }
}