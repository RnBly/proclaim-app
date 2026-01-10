/**
 * bible_book.dart
 * 
 * 성경 66권의 정보를 담은 모델
 * 
 * 주요 기능:
 * - 구약 39권, 신약 27권 데이터
 * - 각 책의 장 수 정보
 * - 한글/영어 이름 매핑
 */

class BibleBook {
  final String koreanName;      // 한글 이름 (예: "창세기")
  final String koreanShort;     // 한글 약자 (예: "창")
  final String englishName;     // 영어 이름 (예: "Genesis")
  final String englishShort;    // 영어 약자 (예: "Gen")
  final int totalChapters;      // 총 장 수
  final bool isOldTestament;    // 구약 여부

  BibleBook({
    required this.koreanName,
    required this.koreanShort,
    required this.englishName,
    required this.englishShort,
    required this.totalChapters,
    required this.isOldTestament,
  });

  // 특정 장의 절 수 반환 (실제 데이터는 BibleService에서 가져옴)
  static List<BibleBook> getAllBooks() {
    return [
      // ===== 구약 39권 =====
      BibleBook(koreanName: '창세기', koreanShort: '창', englishName: 'Genesis', englishShort: 'Gen', totalChapters: 50, isOldTestament: true),
      BibleBook(koreanName: '출애굽기', koreanShort: '출', englishName: 'Exodus', englishShort: 'Exo', totalChapters: 40, isOldTestament: true),
      BibleBook(koreanName: '레위기', koreanShort: '레', englishName: 'Leviticus', englishShort: 'Lev', totalChapters: 27, isOldTestament: true),
      BibleBook(koreanName: '민수기', koreanShort: '민', englishName: 'Numbers', englishShort: 'Num', totalChapters: 36, isOldTestament: true),
      BibleBook(koreanName: '신명기', koreanShort: '신', englishName: 'Deuteronomy', englishShort: 'Deu', totalChapters: 34, isOldTestament: true),
      BibleBook(koreanName: '여호수아', koreanShort: '수', englishName: 'Joshua', englishShort: 'Jos', totalChapters: 24, isOldTestament: true),
      BibleBook(koreanName: '사사기', koreanShort: '삿', englishName: 'Judges', englishShort: 'Jdg', totalChapters: 21, isOldTestament: true),
      BibleBook(koreanName: '룻기', koreanShort: '룻', englishName: 'Ruth', englishShort: 'Rut', totalChapters: 4, isOldTestament: true),
      BibleBook(koreanName: '사무엘상', koreanShort: '삼상', englishName: '1 Samuel', englishShort: '1Sa', totalChapters: 31, isOldTestament: true),
      BibleBook(koreanName: '사무엘하', koreanShort: '삼하', englishName: '2 Samuel', englishShort: '2Sa', totalChapters: 24, isOldTestament: true),
      BibleBook(koreanName: '열왕기상', koreanShort: '왕상', englishName: '1 Kings', englishShort: '1Ki', totalChapters: 22, isOldTestament: true),
      BibleBook(koreanName: '열왕기하', koreanShort: '왕하', englishName: '2 Kings', englishShort: '2Ki', totalChapters: 25, isOldTestament: true),
      BibleBook(koreanName: '역대상', koreanShort: '대상', englishName: '1 Chronicles', englishShort: '1Ch', totalChapters: 29, isOldTestament: true),
      BibleBook(koreanName: '역대하', koreanShort: '대하', englishName: '2 Chronicles', englishShort: '2Ch', totalChapters: 36, isOldTestament: true),
      BibleBook(koreanName: '에스라', koreanShort: '스', englishName: 'Ezra', englishShort: 'Ezr', totalChapters: 10, isOldTestament: true),
      BibleBook(koreanName: '느헤미야', koreanShort: '느', englishName: 'Nehemiah', englishShort: 'Neh', totalChapters: 13, isOldTestament: true),
      BibleBook(koreanName: '에스더', koreanShort: '에', englishName: 'Esther', englishShort: 'Est', totalChapters: 10, isOldTestament: true),
      BibleBook(koreanName: '욥기', koreanShort: '욥', englishName: 'Job', englishShort: 'Job', totalChapters: 42, isOldTestament: true),
      BibleBook(koreanName: '시편', koreanShort: '시', englishName: 'Psalms', englishShort: 'Ps', totalChapters: 150, isOldTestament: true),
      BibleBook(koreanName: '잠언', koreanShort: '잠', englishName: 'Proverbs', englishShort: 'Pro', totalChapters: 31, isOldTestament: true),
      BibleBook(koreanName: '전도서', koreanShort: '전', englishName: 'Ecclesiastes', englishShort: 'Ecc', totalChapters: 12, isOldTestament: true),
      BibleBook(koreanName: '아가', koreanShort: '아', englishName: 'Song of Solomon', englishShort: 'Son', totalChapters: 8, isOldTestament: true),
      BibleBook(koreanName: '이사야', koreanShort: '사', englishName: 'Isaiah', englishShort: 'Isa', totalChapters: 66, isOldTestament: true),
      BibleBook(koreanName: '예레미야', koreanShort: '렘', englishName: 'Jeremiah', englishShort: 'Jer', totalChapters: 52, isOldTestament: true),
      BibleBook(koreanName: '예레미야애가', koreanShort: '애', englishName: 'Lamentations', englishShort: 'Lam', totalChapters: 5, isOldTestament: true),
      BibleBook(koreanName: '에스겔', koreanShort: '겔', englishName: 'Ezekiel', englishShort: 'Eze', totalChapters: 48, isOldTestament: true),
      BibleBook(koreanName: '다니엘', koreanShort: '단', englishName: 'Daniel', englishShort: 'Dan', totalChapters: 12, isOldTestament: true),
      BibleBook(koreanName: '호세아', koreanShort: '호', englishName: 'Hosea', englishShort: 'Hos', totalChapters: 14, isOldTestament: true),
      BibleBook(koreanName: '요엘', koreanShort: '욜', englishName: 'Joel', englishShort: 'Joe', totalChapters: 3, isOldTestament: true),
      BibleBook(koreanName: '아모스', koreanShort: '암', englishName: 'Amos', englishShort: 'Amo', totalChapters: 9, isOldTestament: true),
      BibleBook(koreanName: '오바댜', koreanShort: '옵', englishName: 'Obadiah', englishShort: 'Oba', totalChapters: 1, isOldTestament: true),
      BibleBook(koreanName: '요나', koreanShort: '욘', englishName: 'Jonah', englishShort: 'Jon', totalChapters: 4, isOldTestament: true),
      BibleBook(koreanName: '미가', koreanShort: '미', englishName: 'Micah', englishShort: 'Mic', totalChapters: 7, isOldTestament: true),
      BibleBook(koreanName: '나훔', koreanShort: '나', englishName: 'Nahum', englishShort: 'Nah', totalChapters: 3, isOldTestament: true),
      BibleBook(koreanName: '하박국', koreanShort: '합', englishName: 'Habakkuk', englishShort: 'Hab', totalChapters: 3, isOldTestament: true),
      BibleBook(koreanName: '스바냐', koreanShort: '습', englishName: 'Zephaniah', englishShort: 'Zep', totalChapters: 3, isOldTestament: true),
      BibleBook(koreanName: '학개', koreanShort: '학', englishName: 'Haggai', englishShort: 'Hag', totalChapters: 2, isOldTestament: true),
      BibleBook(koreanName: '스가랴', koreanShort: '슥', englishName: 'Zechariah', englishShort: 'Zec', totalChapters: 14, isOldTestament: true),
      BibleBook(koreanName: '말라기', koreanShort: '말', englishName: 'Malachi', englishShort: 'Mal', totalChapters: 4, isOldTestament: true),
      
      // ===== 신약 27권 =====
      BibleBook(koreanName: '마태복음', koreanShort: '마', englishName: 'Matthew', englishShort: 'Mat', totalChapters: 28, isOldTestament: false),
      BibleBook(koreanName: '마가복음', koreanShort: '막', englishName: 'Mark', englishShort: 'Mar', totalChapters: 16, isOldTestament: false),
      BibleBook(koreanName: '누가복음', koreanShort: '눅', englishName: 'Luke', englishShort: 'Luk', totalChapters: 24, isOldTestament: false),
      BibleBook(koreanName: '요한복음', koreanShort: '요', englishName: 'John', englishShort: 'Joh', totalChapters: 21, isOldTestament: false),
      BibleBook(koreanName: '사도행전', koreanShort: '행', englishName: 'Acts', englishShort: 'Act', totalChapters: 28, isOldTestament: false),
      BibleBook(koreanName: '로마서', koreanShort: '롬', englishName: 'Romans', englishShort: 'Rom', totalChapters: 16, isOldTestament: false),
      BibleBook(koreanName: '고린도전서', koreanShort: '고전', englishName: '1 Corinthians', englishShort: '1Co', totalChapters: 16, isOldTestament: false),
      BibleBook(koreanName: '고린도후서', koreanShort: '고후', englishName: '2 Corinthians', englishShort: '2Co', totalChapters: 13, isOldTestament: false),
      BibleBook(koreanName: '갈라디아서', koreanShort: '갈', englishName: 'Galatians', englishShort: 'Gal', totalChapters: 6, isOldTestament: false),
      BibleBook(koreanName: '에베소서', koreanShort: '엡', englishName: 'Ephesians', englishShort: 'Eph', totalChapters: 6, isOldTestament: false),
      BibleBook(koreanName: '빌립보서', koreanShort: '빌', englishName: 'Philippians', englishShort: 'Phi', totalChapters: 4, isOldTestament: false),
      BibleBook(koreanName: '골로새서', koreanShort: '골', englishName: 'Colossians', englishShort: 'Col', totalChapters: 4, isOldTestament: false),
      BibleBook(koreanName: '데살로니가전서', koreanShort: '살전', englishName: '1 Thessalonians', englishShort: '1Th', totalChapters: 5, isOldTestament: false),
      BibleBook(koreanName: '데살로니가후서', koreanShort: '살후', englishName: '2 Thessalonians', englishShort: '2Th', totalChapters: 3, isOldTestament: false),
      BibleBook(koreanName: '디모데전서', koreanShort: '딤전', englishName: '1 Timothy', englishShort: '1Ti', totalChapters: 6, isOldTestament: false),
      BibleBook(koreanName: '디모데후서', koreanShort: '딤후', englishName: '2 Timothy', englishShort: '2Ti', totalChapters: 4, isOldTestament: false),
      BibleBook(koreanName: '디도서', koreanShort: '딛', englishName: 'Titus', englishShort: 'Tit', totalChapters: 3, isOldTestament: false),
      BibleBook(koreanName: '빌레몬서', koreanShort: '몬', englishName: 'Philemon', englishShort: 'Phm', totalChapters: 1, isOldTestament: false),
      BibleBook(koreanName: '히브리서', koreanShort: '히', englishName: 'Hebrews', englishShort: 'Heb', totalChapters: 13, isOldTestament: false),
      BibleBook(koreanName: '야고보서', koreanShort: '약', englishName: 'James', englishShort: 'Jam', totalChapters: 5, isOldTestament: false),
      BibleBook(koreanName: '베드로전서', koreanShort: '벧전', englishName: '1 Peter', englishShort: '1Pe', totalChapters: 5, isOldTestament: false),
      BibleBook(koreanName: '베드로후서', koreanShort: '벧후', englishName: '2 Peter', englishShort: '2Pe', totalChapters: 3, isOldTestament: false),
      BibleBook(koreanName: '요한1서', koreanShort: '요일', englishName: '1 John', englishShort: '1Jo', totalChapters: 5, isOldTestament: false),
      BibleBook(koreanName: '요한2서', koreanShort: '요이', englishName: '2 John', englishShort: '2Jo', totalChapters: 1, isOldTestament: false),
      BibleBook(koreanName: '요한3서', koreanShort: '요삼', englishName: '3 John', englishShort: '3Jo', totalChapters: 1, isOldTestament: false),
      BibleBook(koreanName: '유다서', koreanShort: '유', englishName: 'Jude', englishShort: 'Jud', totalChapters: 1, isOldTestament: false),
      BibleBook(koreanName: '요한계시록', koreanShort: '계', englishName: 'Revelation', englishShort: 'Rev', totalChapters: 22, isOldTestament: false),
    ];
  }

  // 구약 39권만 반환
  static List<BibleBook> getOldTestamentBooks() {
    return getAllBooks().where((book) => book.isOldTestament).toList();
  }

  // 신약 27권만 반환
  static List<BibleBook> getNewTestamentBooks() {
    return getAllBooks().where((book) => !book.isOldTestament).toList();
  }
}