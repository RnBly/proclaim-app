/**
 * bible_reading.dart
 * 
 * 성경 읽기와 관련된 데이터 모델들을 정의하는 파일
 * 
 * 포함된 클래스:
 * - BibleReading: 일일 성경 읽기 계획 데이터
 * - Verse: 개별 성경 구절
 * - SelectedVerse: 사용자가 선택한 한글 성경 구절
 * - SelectedVerseEsv: 사용자가 선택한 영어 성경 구절 (ESV)
 * - SelectedVerseCompare: 한글-영어 비교용 구절
 * 
 * 데이터 흐름:
 * Google Sheets → BibleReading → UI 표시
 * JSON 파일 → Verse → SelectedVerse → 복사/묵상 기능
 */

/**
 * BibleReading 클래스
 * 
 * 맥체인 성경읽기표의 하루치 읽기 계획을 나타내는 모델
 * Google Sheets에서 CSV로 가져온 데이터를 파싱하여 생성
 * 
 * 데이터 출처:
 * - Google Sheets의 Old Testament, Psalms, New Testament 시트
 * 
 * 사용 위치:
 * - BibleService: Google Sheets에서 읽기 계획 로드
 * - HomeScreen: 오늘의 읽기 계획 표시
 * - BiblePage: 성경 본문 표시
 */
class BibleReading {
  /// 날짜 (형식: "1/1", "12/31" 등)
  /// Google Sheets의 Date 컬럼에서 가져옴
  final String date;
  
  /// 책 이름 약자 (한글) - 예: "창", "출", "시", "마"
  /// Google Sheets의 Book 컬럼에서 가져옴
  final String book;
  
  /// 책 이름 약자 (영어) - 예: "Gen", "Exo", "Ps", "Mat"
  /// Google Sheets의 Book(ENG) 컬럼에서 가져옴
  final String bookEng;
  
  /// 시작 장 번호
  /// Google Sheets의 Start Chapter 컬럼에서 가져옴
  final int startChapter;
  
  /// 끝 장 번호
  /// 한 장만 읽는 경우 startChapter와 같은 값
  /// Google Sheets의 End Chapter 컬럼에서 가져옴
  final int endChapter;
  
  /// 책 전체 이름 (한글) - 예: "창세기", "출애굽기", "시편", "마태복음"
  /// Google Sheets의 Full Name 컬럼에서 가져옴
  final String fullName;
  
  /// 책 전체 이름 (영어) - 예: "Genesis", "Exodus", "Psalms", "Matthew"
  /// Google Sheets의 Full Name(ENG) 컬럼에서 가져옴
  final String fullNameEng;
  
  /// 특정 절 범위 (선택사항) - 예: "1-10"
  /// 전체 장을 읽지 않고 특정 절만 읽을 때 사용
  /// Google Sheets의 Verse 컬럼에서 가져옴
  final String? verseRange;

  /**
   * BibleReading 생성자
   * 
   * @param date 날짜 문자열
   * @param book 책 이름 약자 (한글)
   * @param bookEng 책 이름 약자 (영어)
   * @param startChapter 시작 장
   * @param endChapter 끝 장
   * @param fullName 책 전체 이름 (한글)
   * @param fullNameEng 책 전체 이름 (영어)
   * @param verseRange 절 범위 (선택사항)
   */
  BibleReading({
    required this.date,
    required this.book,
    required this.bookEng,
    required this.startChapter,
    required this.endChapter,
    required this.fullName,
    required this.fullNameEng,
    this.verseRange,
  });

  /**
   * Map에서 BibleReading 객체 생성 (Factory Constructor)
   * 
   * Google Sheets CSV 데이터를 파싱하여 BibleReading 객체로 변환
   * 
   * @param map Google Sheets에서 파싱된 Map 데이터
   * @return BibleReading 객체
   * 
   * Map 구조 예시:
   * {
   *   'Date': '1/1',
   *   'Book': '창',
   *   'Book(ENG)': 'Gen',
   *   'Start Chapter': 1,
   *   'End Chapter': 3,
   *   'Full Name': '창세기',
   *   'Full Name(ENG)': 'Genesis',
   *   'Verse': null  // 또는 "1-10"
   * }
   */
  factory BibleReading.fromMap(Map<String, dynamic> map) {
    return BibleReading(
      date: map['Date'].toString(),
      book: map['Book'] as String,
      bookEng: map['Book(ENG)'] as String,
      startChapter: map['Start Chapter'] as int,
      endChapter: map['End Chapter'] as int,
      fullName: map['Full Name'] as String,
      fullNameEng: map['Full Name(ENG)'] as String,
      verseRange: map['Verse']?.toString(),
    );
  }
}

/**
 * Verse 클래스
 * 
 * 개별 성경 구절을 나타내는 기본 모델
 * JSON 파일에서 로드된 성경 본문의 각 절을 표현
 * 
 * 사용 위치:
 * - BibleService: JSON 파일에서 성경 본문 로드 시 사용
 * - BiblePage: 성경 본문을 화면에 표시할 때 사용
 */
class Verse {
  /// 책 이름 약자 - 예: "창", "출", "시"
  final String book;
  
  /// 장 번호
  final int chapter;
  
  /// 절 번호
  final int verseNumber;
  
  /// 구절 본문 텍스트
  final String text;

  /**
   * Verse 생성자
   * 
   * @param book 책 이름
   * @param chapter 장 번호
   * @param verseNumber 절 번호
   * @param text 구절 본문
   */
  Verse({
    required this.book,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  /**
   * 구절의 고유 키 생성
   * 
   * 형식: "책이름-장-절" (예: "창-1-1")
   * 
   * 용도:
   * - Map의 키로 사용하여 빠른 검색
   * - 구절 비교 및 중복 체크
   * 
   * @return 구절 고유 키
   */
  String get key => '$book-$chapter-$verseNumber';
}

/**
 * SelectedVerse 클래스
 * 
 * 사용자가 선택한 한글 성경 구절을 나타내는 모델
 * Verse 클래스와 유사하지만 fullName(책 전체 이름)을 포함
 * 
 * 사용 위치:
 * - VerseSelectionDialog: 사용자가 구절 선택 시 생성
 * - CopyDialog: 구절 복사 기능
 * - MeditationWritingDialog: 묵상 작성 시 사용
 */
class SelectedVerse {
  /// 책 이름 약자 (한글) - 예: "창", "시", "마"
  final String book;
  
  /// 책 전체 이름 (한글) - 예: "창세기", "시편", "마태복음"
  /// 복사 및 표시 시 사용
  final String fullName;
  
  /// 장 번호
  final int chapter;
  
  /// 절 번호
  final int verseNumber;
  
  /// 구절 본문 텍스트 (한글)
  final String text;

  /**
   * SelectedVerse 생성자
   * 
   * @param book 책 이름 약자
   * @param fullName 책 전체 이름
   * @param chapter 장 번호
   * @param verseNumber 절 번호
   * @param text 구절 본문
   */
  SelectedVerse({
    required this.book,
    required this.fullName,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  /**
   * 구절의 고유 키 생성
   * 
   * 형식: "책이름-장-절" (예: "창-1-1")
   * 
   * @return 구절 고유 키
   */
  String get key => '$book-$chapter-$verseNumber';
}

/**
 * SelectedVerseEsv 클래스
 * 
 * 사용자가 선택한 영어 성경 구절 (ESV)을 나타내는 모델
 * SelectedVerse의 영어 버전
 * 
 * 사용 위치:
 * - VerseSelectionDialog: ESV 모드에서 구절 선택 시
 * - CopyDialog: ESV 구절 복사 기능
 */
class SelectedVerseEsv {
  /// 책 이름 약자 (영어) - 예: "Gen", "Ps", "Mat"
  final String bookEng;
  
  /// 책 전체 이름 (영어) - 예: "Genesis", "Psalms", "Matthew"
  final String fullNameEng;
  
  /// 장 번호
  final int chapter;
  
  /// 절 번호
  final int verseNumber;
  
  /// 구절 본문 텍스트 (영어)
  final String text;

  /**
   * SelectedVerseEsv 생성자
   * 
   * @param bookEng 책 이름 약자 (영어)
   * @param fullNameEng 책 전체 이름 (영어)
   * @param chapter 장 번호
   * @param verseNumber 절 번호
   * @param text 구절 본문 (영어)
   */
  SelectedVerseEsv({
    required this.bookEng,
    required this.fullNameEng,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  /**
   * 구절의 고유 키 생성
   * 
   * 형식: "책이름-장-절" (예: "Gen-1-1")
   * 
   * @return 구절 고유 키
   */
  String get key => '$bookEng-$chapter-$verseNumber';
}

/**
 * SelectedVerseCompare 클래스
 * 
 * 한글-영어 비교 모드에서 선택한 구절을 나타내는 모델
 * 한글 본문과 영어 본문을 함께 포함
 * 
 * 사용 위치:
 * - VerseSelectionDialog: 비교 모드에서 구절 선택 시
 * - CopyDialog: 한영 비교 복사 기능
 */
class SelectedVerseCompare {
  /// 책 이름 약자 (한글)
  final String book;
  
  /// 책 전체 이름 (한글)
  final String fullName;
  
  /// 장 번호
  final int chapter;
  
  /// 절 번호
  final int verseNumber;
  
  /// 구절 본문 (한글)
  final String koreanText;
  
  /// 구절 본문 (영어)
  final String englishText;

  /**
   * SelectedVerseCompare 생성자
   * 
   * @param book 책 이름 약자
   * @param fullName 책 전체 이름
   * @param chapter 장 번호
   * @param verseNumber 절 번호
   * @param koreanText 한글 본문
   * @param englishText 영어 본문
   */
  SelectedVerseCompare({
    required this.book,
    required this.fullName,
    required this.chapter,
    required this.verseNumber,
    required this.koreanText,
    required this.englishText,
  });

  /**
   * 구절의 고유 키 생성
   * 
   * 형식: "책이름-장-절" (예: "창-1-1")
   * 
   * @return 구절 고유 키
   */
  String get key => '$book-$chapter-$verseNumber';
}
