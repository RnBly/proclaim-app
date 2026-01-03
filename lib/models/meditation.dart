/**
 * meditation.dart
 * 
 * 묵상 기능과 관련된 데이터 모델을 정의하는 파일
 * 
 * 포함된 클래스:
 * - Meditation: 사용자의 성경 묵상 데이터
 * - VerseReference: 묵상에 포함된 성경 구절 참조
 * 
 * 데이터 흐름:
 * 1. 사용자가 성경 구절 선택 → VerseReference 생성
 * 2. 묵상 내용 작성 + 하이라이트 색상 선택
 * 3. Meditation 객체 생성
 * 4. Firestore에 JSON 형태로 저장
 * 5. 나중에 불러올 때 JSON → Meditation 객체로 복원
 * 
 * Firestore 저장 구조:
 * /meditations/{meditationId}
 *   - id: 묵상 고유 ID
 *   - userId: 사용자 ID
 *   - verses: [ {book, chapter, verse, text}, ... ]
 *   - content: 묵상 내용
 *   - highlightColor: 하이라이트 색상 ('yellow', 'blue' 등)
 *   - createdAt: 생성 시간 (ISO 8601)
 *   - updatedAt: 수정 시간 (ISO 8601)
 */

/**
 * Meditation 클래스
 * 
 * 사용자의 성경 묵상 데이터를 나타내는 모델
 * Firestore에 저장되는 묵상 문서의 구조를 정의
 * 
 * 특징:
 * - 여러 개의 성경 구절을 포함 가능 (verses 리스트)
 * - 하이라이트 색상을 지정하여 시각적 구분
 * - 생성/수정 시간 자동 추적
 * 
 * 사용 위치:
 * - MeditationService: Firestore CRUD 작업
 * - MeditationWritingDialog: 묵상 작성/수정
 * - MeditationViewDialog: 저장된 묵상 보기
 * - HomeScreen: 오늘의 묵상 목록 표시
 */
class Meditation {
  /// 묵상 고유 ID
  /// Firestore 문서 ID로 사용 (UUID 또는 timestamp 기반)
  final String id;
  
  /// 사용자 ID
  /// Firebase Authentication의 user.uid
  /// 묵상 데이터를 사용자별로 구분하기 위해 사용
  final String userId;
  
  /// 선택된 성경 구절 목록
  /// 하나의 묵상에 여러 구절을 포함 가능
  /// 각 구절은 VerseReference 객체로 표현
  final List<VerseReference> verses;
  
  /// 묵상 내용 (사용자가 작성한 텍스트)
  /// 최대 길이 제한은 UI 레벨에서 처리 (보통 1000-2000자)
  final String content;
  
  /// 하이라이트 색상 이름
  /// 'yellow', 'blue', 'red', 'green', 'orange' 중 하나
  /// MeditationColors.colorMap에서 실제 Color 객체로 변환
  final String highlightColor;
  
  /// 생성 시간
  /// 묵상이 처음 작성된 시간
  /// DateTime 객체로 저장되며, JSON 변환 시 ISO 8601 문자열로 변환
  final DateTime createdAt;
  
  /// 수정 시간
  /// 묵상이 마지막으로 수정된 시간
  /// 수정 시 자동 업데이트
  final DateTime updatedAt;

  /**
   * Meditation 생성자
   * 
   * @param id 묵상 고유 ID
   * @param userId 사용자 ID
   * @param verses 선택된 구절 목록
   * @param content 묵상 내용
   * @param highlightColor 하이라이트 색상
   * @param createdAt 생성 시간
   * @param updatedAt 수정 시간
   */
  Meditation({
    required this.id,
    required this.userId,
    required this.verses,
    required this.content,
    required this.highlightColor,
    required this.createdAt,
    required this.updatedAt,
  });

  /**
   * Meditation 객체를 JSON Map으로 변환
   * 
   * Firestore에 저장하거나 네트워크 전송 시 사용
   * 
   * @return JSON Map
   * 
   * 변환 결과 예시:
   * {
   *   'id': 'meditation_123',
   *   'userId': 'user_abc',
   *   'verses': [
   *     {'book': '창세기', 'chapter': 1, 'verse': 1, 'text': '태초에...'},
   *     {'book': '창세기', 'chapter': 1, 'verse': 2, 'text': '땅이...'}
   *   ],
   *   'content': '하나님의 창조 섭리를 묵상합니다...',
   *   'highlightColor': 'yellow',
   *   'createdAt': '2024-01-01T10:00:00.000Z',
   *   'updatedAt': '2024-01-01T11:30:00.000Z'
   * }
   */
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      // verses 리스트의 각 VerseReference를 JSON으로 변환
      'verses': verses.map((v) => v.toJson()).toList(),
      'content': content,
      'highlightColor': highlightColor,
      // DateTime을 ISO 8601 문자열로 변환
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /**
   * JSON Map에서 Meditation 객체 생성 (Factory Constructor)
   * 
   * Firestore에서 데이터를 불러오거나 네트워크에서 받은 데이터를 파싱할 때 사용
   * 
   * @param json JSON Map 데이터
   * @return Meditation 객체
   * 
   * 사용 예:
   * ```dart
   * Map<String, dynamic> data = await firestore.collection('meditations').doc(id).get();
   * Meditation meditation = Meditation.fromJson(data);
   * ```
   */
  factory Meditation.fromJson(Map<String, dynamic> json) {
    return Meditation(
      id: json['id'] as String,
      userId: json['userId'] as String,
      // JSON의 verses 배열을 VerseReference 객체 리스트로 변환
      verses: (json['verses'] as List)
          .map((v) => VerseReference.fromJson(v as Map<String, dynamic>))
          .toList(),
      content: json['content'] as String,
      highlightColor: json['highlightColor'] as String,
      // ISO 8601 문자열을 DateTime으로 파싱
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /**
   * 복사본 생성 메서드 (Immutable Pattern)
   * 
   * 기존 Meditation 객체의 일부 필드만 변경한 새 객체 생성
   * 묵상 수정 시 사용 (특히 updatedAt 갱신)
   * 
   * @param id 새 ID (선택)
   * @param userId 새 사용자 ID (선택)
   * @param verses 새 구절 목록 (선택)
   * @param content 새 묵상 내용 (선택)
   * @param highlightColor 새 하이라이트 색상 (선택)
   * @param createdAt 새 생성 시간 (선택)
   * @param updatedAt 새 수정 시간 (선택)
   * @return 수정된 새 Meditation 객체
   * 
   * 사용 예:
   * ```dart
   * Meditation updated = existingMeditation.copyWith(
   *   content: '수정된 묵상 내용',
   *   updatedAt: DateTime.now(),
   * );
   * ```
   */
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

/**
 * VerseReference 클래스
 * 
 * 묵상에 포함된 개별 성경 구절을 나타내는 모델
 * 
 * 특징:
 * - 성경 구절의 위치 정보 (책, 장, 절)
 * - 구절 본문 텍스트 포함
 * - 동등성 비교 및 해시 코드 구현 (Set, Map 사용 가능)
 * 
 * 사용 위치:
 * - Meditation 클래스 내부에서 구절 목록으로 사용
 * - VerseSelectionDialog: 구절 선택 시 생성
 * - MeditationViewDialog: 저장된 구절 표시
 */
class VerseReference {
  /// 책 이름 (한글) - 예: "창세기", "시편", "마태복음"
  final String book;
  
  /// 장 번호
  final int chapter;
  
  /// 절 번호
  final int verse;
  
  /// 구절 본문 텍스트
  final String text;

  /**
   * VerseReference 생성자
   * 
   * @param book 책 이름
   * @param chapter 장 번호
   * @param verse 절 번호
   * @param text 구절 본문
   */
  VerseReference({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  /**
   * VerseReference를 JSON Map으로 변환
   * 
   * Meditation.toJson() 내부에서 호출됨
   * 
   * @return JSON Map
   * 
   * 변환 결과 예시:
   * {
   *   'book': '창세기',
   *   'chapter': 1,
   *   'verse': 1,
   *   'text': '태초에 하나님이 천지를 창조하시니라'
   * }
   */
  Map<String, dynamic> toJson() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }

  /**
   * JSON Map에서 VerseReference 생성 (Factory Constructor)
   * 
   * Meditation.fromJson() 내부에서 호출됨
   * 
   * @param json JSON Map 데이터
   * @return VerseReference 객체
   */
  factory VerseReference.fromJson(Map<String, dynamic> json) {
    return VerseReference(
      book: json['book'] as String,
      chapter: json['chapter'] as int,
      verse: json['verse'] as int,
      text: json['text'] as String,
    );
  }

  /**
   * UI 표시용 문자열 생성 (Getter)
   * 
   * 구절 참조를 간단한 문자열로 표현
   * 
   * @return "책이름 장:절" 형식의 문자열
   * 
   * 예시:
   * - "창세기 1:1"
   * - "시편 23:1"
   * - "요한복음 3:16"
   * 
   * 사용 위치:
   * - MeditationViewDialog: 구절 참조 표시
   * - 묵상 목록에서 간단한 구절 정보 표시
   */
  String get displayText => '$book $chapter:$verse';

  /**
   * 동등성 비교 연산자 오버라이드
   * 
   * 두 VerseReference가 같은 구절을 가리키는지 확인
   * 본문 텍스트는 비교하지 않고 위치 정보만 비교
   * 
   * @param other 비교 대상 객체
   * @return 같은 구절이면 true, 아니면 false
   * 
   * 사용 예:
   * ```dart
   * VerseReference v1 = VerseReference(book: '창세기', chapter: 1, verse: 1, text: '...');
   * VerseReference v2 = VerseReference(book: '창세기', chapter: 1, verse: 1, text: '...');
   * print(v1 == v2); // true
   * ```
   */
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerseReference &&
        other.book == book &&
        other.chapter == chapter &&
        other.verse == verse;
  }

  /**
   * 해시 코드 생성 오버라이드
   * 
   * == 연산자를 오버라이드했으면 hashCode도 반드시 오버라이드 필요
   * Set, Map 등의 컬렉션에서 객체를 올바르게 비교하기 위해 필수
   * 
   * @return 책, 장, 절을 기반으로 생성된 해시 코드
   */
  @override
  int get hashCode => Object.hash(book, chapter, verse);
}
