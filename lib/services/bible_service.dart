import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/bible_reading.dart';

class BibleService {
  static final BibleService _instance = BibleService._internal();
  factory BibleService() => _instance;
  BibleService._internal();

  // GitHub Raw URLs
  static const String EXCEL_URL =
      'https://raw.githubusercontent.com/RnBly/proclaim-app/main/assets/Proclaim.xlsx';
  static const String BIBLE_JSON_URL =
      'https://raw.githubusercontent.com/RnBly/proclaim-app/main/assets/bible.json';
  static const String BIBLE_ESV_JSON_URL =
      'https://raw.githubusercontent.com/RnBly/proclaim-app/main/assets/bible_esv.json';

  Map<String, dynamic>? _bibleData;
  Map<String, dynamic>? _bibleEsvData;
  List<BibleReading>? _oldTestamentData;
  List<BibleReading>? _psalmsData;
  List<BibleReading>? _newTestamentData;

  Future<void> initialize() async {
    try {
      await _loadFromRemote();
    } catch (e) {
      print('Remote load failed, using local assets: $e');
      await _loadFromAssets();
    }
  }

  // 원격 파일에서 로드
  Future<void> _loadFromRemote() async {
    final directory = await getApplicationDocumentsDirectory();
    final excelPath = '${directory.path}/Proclaim.xlsx';
    final jsonPath = '${directory.path}/bible.json';
    final esvJsonPath = '${directory.path}/bible_esv.json';

    await _downloadFile(EXCEL_URL, excelPath);
    await _downloadFile(BIBLE_JSON_URL, jsonPath);
    await _downloadFile(BIBLE_ESV_JSON_URL, esvJsonPath);

    await _loadExcelFromFile(excelPath);
    await _loadBibleJsonFromFile(jsonPath);
    await _loadBibleEsvJsonFromFile(esvJsonPath);
  }

  // 파일 다운로드
  Future<void> _downloadFile(String url, String savePath) async {
    final file = File(savePath);

    // 24시간 이내 파일이 있으면 건너뛰기
    if (await file.exists()) {
      final lastModified = await file.lastModified();
      if (DateTime.now().difference(lastModified).inHours < 24) {
        print('Using cached file: $savePath');
        return;
      }
    }

    print('Downloading: $url');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      print('Downloaded: $savePath');
    } else {
      throw Exception('Failed to download: $url');
    }
  }

  // 로컬 파일에서 엑셀 로드
  Future<void> _loadExcelFromFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final excel = Excel.decodeBytes(bytes);

    _oldTestamentData = _parseSheet(excel, 'Old Testament');
    _psalmsData = _parseSheet(excel, 'Psalms');
    _newTestamentData = _parseSheet(excel, 'New Testament');
  }

  // 로컬 파일에서 JSON 로드
  Future<void> _loadBibleJsonFromFile(String path) async {
    final String jsonString = await File(path).readAsString();
    _bibleData = json.decode(jsonString);
  }

  // 로컬 파일에서 ESV JSON 로드
  Future<void> _loadBibleEsvJsonFromFile(String path) async {
    final String jsonString = await File(path).readAsString();
    _bibleEsvData = json.decode(jsonString);
    _cleanEsvQuotes();
  }

  // Assets에서 로드 (백업용)
  Future<void> _loadFromAssets() async {
    await _loadBibleJson();
    await _loadBibleEsvJson();
    await _loadExcel();
  }

  Future<void> _loadBibleJson() async {
    final String jsonString = await rootBundle.loadString('assets/bible.json');
    _bibleData = json.decode(jsonString);
  }

  Future<void> _loadBibleEsvJson() async {
    final String jsonString = await rootBundle.loadString('assets/bible_esv.json');
    _bibleEsvData = json.decode(jsonString);
    _cleanEsvQuotes();
  }

  // ESV JSON의 이스케이프된 따옴표 정리
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
          'Verse': row[7]?.value.toString(),  // ← 이 줄이 있어야 함!
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
    print('getVerses called: book=$book, chapters=$startChapter-$endChapter, verseRange=$verseRange'); // ← 추가!

    final List<Verse> verses = [];

    if (_bibleData == null || _bibleData![book] == null) return verses;

    final bookData = _bibleData![book] as Map<String, dynamic>;

    // 절 범위 파싱
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


  // ESV 구절 가져오기
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

  // 수동 새로고침 (강제 다운로드)
  Future<void> forceRefresh() async {
    final directory = await getApplicationDocumentsDirectory();
    final excelPath = '${directory.path}/Proclaim.xlsx';
    final jsonPath = '${directory.path}/bible.json';
    final esvJsonPath = '${directory.path}/bible_esv.json';

    // 캐시 파일 삭제
    final excelFile = File(excelPath);
    final jsonFile = File(jsonPath);
    final esvJsonFile = File(esvJsonPath);

    if (await excelFile.exists()) await excelFile.delete();
    if (await jsonFile.exists()) await jsonFile.delete();
    if (await esvJsonFile.exists()) await esvJsonFile.delete();

    // 새로 다운로드
    await _loadFromRemote();
  }
}