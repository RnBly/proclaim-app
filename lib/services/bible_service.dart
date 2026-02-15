/**
 * bible_service.dart
 * 
 * 성경 데이터 로딩 및 관리를 담당하는 핵심 서비스
 * 
 * 주요 역할:
 * 1. 맥체인 성경읽기표 로딩 (Google Sheets → Excel 백업)
 * 2. 성경 본문 로딩 (GitHub JSON → Assets 백업)
 * 3. 날짜별 읽기 계획 조회
 * 4. 성경 본문 조회 (한글/영어/비교)
 * 5. 선택된 구절 포맷팅 (복사 기능용)
 * 
 * 데이터 소스 우선순위:
 * - 읽기 계획: Google Sheets (1순위) → Excel Assets (2순위)
 * - 성경 본문: GitHub Raw (1순위) → Assets (2순위)
 * 
 * 캐싱: GitHub JSON 파일은 24시간 캐시
 * 
 * 디자인 패턴: Singleton 패턴
 */

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
  
  // 한 달 통독 데이터
  List<BibleReading>? _monthlyReadingData;
  List<BibleReading>? _monthlyPsalmsData;

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

  // ===== 한 달 통독 데이터 로드 =====
  
  Future<void> loadMonthlyReadingPlan() async {
    if (_monthlyReadingData != null && _monthlyPsalmsData != null) {
      print('✅ Monthly reading plan already loaded');
      return;
    }

    print('📊 Loading monthly reading plan from Google Sheets...');

    try {
      final results = await Future.wait([
        _fetchSheetAsCsv(Secrets.MONTHLY_READING_SHEET),
        _fetchSheetAsCsv(Secrets.MONTHLY_PSALMS_SHEET),
      ]);

      _monthlyReadingData = _parseCsvData(results[0]);
      _monthlyPsalmsData = _parseCsvData(results[1]);

      print('  ✓ Monthly Reading: ${_monthlyReadingData?.length ?? 0} entries');
      print('  ✓ Monthly Psalms: ${_monthlyPsalmsData?.length ?? 0} entries');
    } catch (e) {
      print('⚠️ Failed to load monthly reading plan: $e');
      _monthlyReadingData = [];
      _monthlyPsalmsData = [];
    }
  }

  // 날짜를 기준으로 한 달 통독 본문 가져오기 (1~30일)
  // 한 날짜에 여러 책이 있을 수 있으므로 리스트로 반환
  List<BibleReading> getAllMonthlyReadings(DateTime date) {
    if (_monthlyReadingData == null || _monthlyReadingData!.isEmpty) {
      return [];
    }
    
    int dayOfMonth = _calculateReadingDay(date);
    
    // 같은 날짜의 모든 reading 찾기
    final results = <BibleReading>[];
    for (var reading in _monthlyReadingData!) {
      // date 필드가 "14" 또는 "14일" 같은 형식일 수 있음
      final readingDay = int.tryParse(reading.date.replaceAll(RegExp(r'[^0-9]'), ''));
      if (readingDay == dayOfMonth) {
        results.add(reading);
      }
    }
    
    return results;
  }

  List<BibleReading> getAllMonthlyPsalms(DateTime date) {
    if (_monthlyPsalmsData == null || _monthlyPsalmsData!.isEmpty) {
      return [];
    }
    
    int dayOfMonth = _calculateReadingDay(date);
    
    // 같은 날짜의 모든 reading 찾기
    final results = <BibleReading>[];
    for (var reading in _monthlyPsalmsData!) {
      final readingDay = int.tryParse(reading.date.replaceAll(RegExp(r'[^0-9]'), ''));
      if (readingDay == dayOfMonth) {
        results.add(reading);
      }
    }
    
    return results;
  }

  /// 1~3월 특별 로직: 30일 사이클을 유지하면서 31일이 있는 달의 본문도 읽을 수 있도록 함
  /// 
  /// 로직:
  /// - 1월: 1~30일 = 1~30일차, 31일 = 1일차
  /// - 2월: 1~28일 = 2~29일차  
  /// - 3월: 1일 = 30일차, 2~31일 = 1~30일차
  /// - 4월~12월: 기존대로 매월 1~30일 반복
  int _calculateReadingDay(DateTime date) {
    final month = date.month;
    final day = date.day;
    
    // 1~3월 특별 처리
    if (month == 1) {
      // 1월: 1~30일 그대로, 31일은 1일차
      return day <= 30 ? day : 1;
    } else if (month == 2) {
      // 2월: 1일 = 2일차, 2일 = 3일차, ..., 28일 = 29일차
      return day + 1;
    } else if (month == 3) {
      // 3월: 1일 = 30일차, 2일 = 1일차, 3일 = 2일차, ..., 31일 = 30일차
      return day == 1 ? 30 : day - 1;
    }
    
    // 4월~12월: 기존 로직 (31일은 30일로 처리)
    return day > 30 ? 30 : day;
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
        
        // 처음 5개와 마지막 부분의 날짜 형식 로그
        if (i <= 5 || i >= lines.length - 5) {
          print('  CSV Row $i Date: "${row[0]}"');
        }
        
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
    print('📖 getTodayReading called: date=${now.year}-${now.month}-${now.day}, sheetType=$sheetType');
    final reading = getReadingForDate(now, sheetType);
    if (reading != null) {
      print('   ✓ Found reading: ${reading.book}(${reading.bookEng}) ${reading.startChapter}-${reading.endChapter}');
    } else {
      print('   ❌ No reading found!');
    }
    return reading;
  }

  BibleReading? getReadingForDate(DateTime date, String sheetType) {
    final monthDay = DateFormat('MM-dd').format(date);
    final fullDate = DateFormat('yyyy-MM-dd').format(date);

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

    if (data == null || data.isEmpty) {
      print('⚠️ No data available for sheet type: $sheetType');
      return null;
    }

    // 디버그: 처음 5개와 마지막 5개 날짜 출력
    print('🔍 Searching for date: $fullDate (MM-dd: $monthDay) in $sheetType');
    print('   First 5 dates: ${data.take(5).map((r) => r.date).join(", ")}');
    if (data.length > 5) {
      print('   Last 5 dates: ${data.skip(data.length - 5).map((r) => r.date).join(", ")}');
    }

    // 여러 형식으로 날짜 매칭 시도
    BibleReading? result;
    
    // 1. 정확한 전체 날짜 매칭
    result = data.cast<BibleReading?>().firstWhere(
      (reading) => reading?.date == fullDate,
      orElse: () => null,
    );
    
    if (result != null) {
      print('✓ Found exact match: ${result.date}');
      return result;
    }

    // 2. MM-dd 형식 contains 매칭
    result = data.cast<BibleReading?>().firstWhere(
      (reading) => reading?.date.contains(monthDay) ?? false,
      orElse: () => null,
    );
    
    if (result != null) {
      print('✓ Found contains match: ${result.date}');
      return result;
    }

    // 3. 날짜 파싱 후 비교
    for (var reading in data) {
      try {
        // 다양한 형식 시도
        DateTime? readingDate;
        
        // "yyyy-MM-dd" 형식
        if (reading.date.contains('-')) {
          final parts = reading.date.split(' ')[0]; // 시간 부분 제거
          readingDate = DateTime.tryParse(parts);
        }
        // "MM.dd" 형식
        else if (reading.date.contains('.')) {
          final parts = reading.date.split('.');
          if (parts.length >= 2) {
            final month = int.tryParse(parts[0]);
            final day = int.tryParse(parts[1]);
            if (month != null && day != null) {
              readingDate = DateTime(date.year, month, day);
            }
          }
        }

        if (readingDate != null && 
            readingDate.year == date.year &&
            readingDate.month == date.month &&
            readingDate.day == date.day) {
          print('✓ Found parsed match: ${reading.date}');
          return reading;
        }
      } catch (e) {
        // 파싱 실패는 무시하고 계속
      }
    }

    print('❌ No match found! Returning first item as fallback');
    return data.first;
  }

  // 특정 날짜의 모든 읽기 자료를 반환 (같은 날짜에 여러 책이 있을 수 있음)
  List<BibleReading> getAllReadingsForDate(DateTime date, String sheetType) {
    final monthDay = DateFormat('MM-dd').format(date);
    final fullDate = DateFormat('yyyy-MM-dd').format(date);

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
      case 'monthly':
        // 한 달 통독의 경우 날짜의 일(day)을 기준으로 가져오기
        return getAllMonthlyReadings(date);
      case 'monthly_psalms':
        // 한 달 통독 시편의 경우 날짜의 일(day)을 기준으로 가져오기
        return getAllMonthlyPsalms(date);
    }

    if (data == null || data.isEmpty) {
      print('⚠️ No data available for sheet type: $sheetType');
      return [];
    }

    final List<BibleReading> results = [];

    // 여러 형식으로 날짜 매칭 시도 - 모든 매칭 항목 수집
    
    // 1. 정확한 전체 날짜 매칭
    for (var reading in data) {
      if (reading.date == fullDate) {
        results.add(reading);
      }
    }
    
    if (results.isNotEmpty) {
      print('✓ Found ${results.length} exact matches for $fullDate');
      return results;
    }

    // 2. MM-dd 형식 contains 매칭
    for (var reading in data) {
      if (reading.date.contains(monthDay)) {
        results.add(reading);
      }
    }
    
    if (results.isNotEmpty) {
      print('✓ Found ${results.length} contains matches for $monthDay');
      return results;
    }

    // 3. 날짜 파싱 후 비교
    for (var reading in data) {
      try {
        DateTime? readingDate;
        
        if (reading.date.contains('-')) {
          final parts = reading.date.split(' ')[0];
          readingDate = DateTime.tryParse(parts);
        } else if (reading.date.contains('.')) {
          final parts = reading.date.split('.');
          if (parts.length >= 2) {
            final month = int.tryParse(parts[0]);
            final day = int.tryParse(parts[1]);
            if (month != null && day != null) {
              readingDate = DateTime(date.year, month, day);
            }
          }
        }

        if (readingDate != null && 
            readingDate.year == date.year &&
            readingDate.month == date.month &&
            readingDate.day == date.day) {
          results.add(reading);
        }
      } catch (e) {
        // 파싱 실패는 무시하고 계속
      }
    }

    if (results.isNotEmpty) {
      print('✓ Found ${results.length} parsed matches');
      return results;
    }

    print('❌ No matches found! Returning empty list');
    return [];
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
    print('getEsvVerses called: bookEng=$bookEng, chapters=$startChapter-$endChapter, verseRange=$verseRange');
    
    // Book(ENG) 값 정리 (공백, 탭 제거)
    String cleanedBook = bookEng.trim();
    print('  Cleaned bookEng: "$bookEng" → "$cleanedBook"');
    
    final List<Verse> verses = [];

    if (_bibleEsvData == null) {
      print('  ❌ ESV data not loaded');
      return verses;
    }
    
    if (_bibleEsvData![cleanedBook] == null) {
      print('  ❌ Book not found in ESV data: $cleanedBook');
      print('  Available keys sample: ${_bibleEsvData!.keys.take(10).join(", ")}');
      return verses;
    }

    final bookData = _bibleEsvData![cleanedBook] as Map<String, dynamic>;
    print('  ✓ Found book with ${bookData.length} chapters');

    int? startVerse;
    int? endVerse;
    if (verseRange != null && verseRange.contains('-')) {
      final parts = verseRange.split('-');
      startVerse = int.tryParse(parts[0].trim());
      endVerse = int.tryParse(parts[1].trim());
    }

    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      final chapterKey = chapter.toString();
      
      if (bookData[chapterKey] == null) {
        print('  ⚠️ Chapter not found: $chapterKey');
        continue;
      }

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
              book: cleanedBook,
              chapter: chapter,
              verseNumber: verseStart,
              text: verseText.toString(),
            ));

            for (int v = verseStart + 1; v <= verseEnd; v++) {
              if (startVerse != null && endVerse != null) {
                if (v < startVerse || v > endVerse) continue;
              }
              verses.add(Verse(
                book: cleanedBook,
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
              book: cleanedBook,
              chapter: chapter,
              verseNumber: verseNum,
              text: verseText.toString(),
            ));
          }
        } catch (e) {
          print('Error parsing verse $cleanedBook $chapter:$verseKey - $e');
        }
      });
    }

    verses.sort((a, b) {
      if (a.chapter != b.chapter) {
        return a.chapter.compareTo(b.chapter);
      }
      return a.verseNumber.compareTo(b.verseNumber);
    });

    print('  ✓ Found ${verses.length} verses');
    return verses;
  }

  String formatSelectedVerses(List<SelectedVerse> verses) {
    if (verses.isEmpty) return '';

    // 정렬 제거 - 사용자가 선택한 순서 그대로 유지
    // verses.sort(...); ← 이 부분 삭제!

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

    // 정렬 제거 - 사용자가 선택한 순서 그대로 유지
    // verses.sort(...); ← 이 부분 삭제!

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

    // 정렬 제거 - 사용자가 선택한 순서 그대로 유지
    // verses.sort(...); ← 이 부분 삭제!

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