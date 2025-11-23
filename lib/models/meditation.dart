class Meditation {
  final String id;
  final String userId;
  final List<VerseReference> verses; // 선택된 구절들
  final String content; // 묵상 내용
  final String highlightColor; // 하이라이트 색상
  final DateTime createdAt;
  final DateTime updatedAt;

  Meditation({
    required this.id,
    required this.userId,
    required this.verses,
    required this.content,
    required this.highlightColor,
    required this.createdAt,
    required this.updatedAt,
  });

  // JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'verses': verses.map((v) => v.toJson()).toList(),
      'content': content,
      'highlightColor': highlightColor,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Meditation.fromJson(Map<String, dynamic> json) {
    return Meditation(
      id: json['id'] as String,
      userId: json['userId'] as String,
      verses: (json['verses'] as List)
          .map((v) => VerseReference.fromJson(v as Map<String, dynamic>))
          .toList(),
      content: json['content'] as String,
      highlightColor: json['highlightColor'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // 복사본 생성 (수정용)
  Meditation copyWith({
    String? id,
    String? userId,
    List<VerseReference>? verses,
    String? content,
    String? highlightColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Meditation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      verses: verses ?? this.verses,
      content: content ?? this.content,
      highlightColor: highlightColor ?? this.highlightColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// 구절 참조 클래스
class VerseReference {
  final String book; // 책 이름
  final int chapter; // 장
  final int verse; // 절
  final String text; // 구절 텍스트

  VerseReference({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }

  factory VerseReference.fromJson(Map<String, dynamic> json) {
    return VerseReference(
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      text: json['text'] as String,
    );
  }

  // 구절 표시용 문자열 생성
  String get displayText => '$book $chapter:$verse';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseReference &&
        other.book == book &&
        other.chapter == chapter &&
        other.verse == verse;
  }

  @override
  int get hashCode => Object.hash(book, chapter, verse);
}