class BibleReading {
  final String date;
  final String book;
  final String bookEng;
  final int startChapter;
  final int endChapter;
  final String fullName;
  final String fullNameEng;
  final String? verseRange; // 추가!

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

class Verse {
  final String book;
  final int chapter;
  final int verseNumber;
  final String text;

  Verse({
    required this.book,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  String get key => '$book-$chapter-$verseNumber';
}

class SelectedVerse {
  final String book;
  final String fullName;
  final int chapter;
  final int verseNumber;
  final String text;

  SelectedVerse({
    required this.book,
    required this.fullName,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  String get key => '$book-$chapter-$verseNumber';
}

class SelectedVerseEsv {
  final String bookEng;
  final String fullNameEng;
  final int chapter;
  final int verseNumber;
  final String text;

  SelectedVerseEsv({
    required this.bookEng,
    required this.fullNameEng,
    required this.chapter,
    required this.verseNumber,
    required this.text,
  });

  String get key => '$bookEng-$chapter-$verseNumber';
}

class SelectedVerseCompare {
  final String book;
  final String fullName;
  final int chapter;
  final int verseNumber;
  final String koreanText;
  final String englishText;

  SelectedVerseCompare({
    required this.book,
    required this.fullName,
    required this.chapter,
    required this.verseNumber,
    required this.koreanText,
    required this.englishText,
  });

  String get key => '$book-$chapter-$verseNumber';
}