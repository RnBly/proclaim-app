/**
 * meditation_service.dart
 * 
 * 묵상 데이터의 CRUD(생성, 읽기, 수정, 삭제) 작업을 담당하는 서비스
 * 
 * 역할:
 * - Firestore에 묵상 데이터 저장/불러오기
 * - 구절별 묵상 검색
 * - 날짜별 묵상 검색
 * - 하이라이트 색상 조회
 * - 메모리 캐싱으로 성능 최적화
 * 
 * Firestore 구조:
 * /users/{userId}/meditations/{meditationId}
 *   - id: 묵상 고유 ID
 *   - userId: 사용자 ID
 *   - verses: 선택된 구절들
 *   - content: 묵상 내용
 *   - highlightColor: 하이라이트 색상
 *   - createdAt: 생성 시간
 *   - updatedAt: 수정 시간
 * 
 * 디자인 패턴:
 * - Singleton 패턴
 * - 캐싱 전략 (메모리 캐시)
 * 
 * 사용 위치:
 * - MeditationWritingDialog: 묵상 저장
 * - MeditationViewDialog: 저장된 묵상 보기
 * - BiblePage: 구절별 하이라이트 표시
 * - HomeScreen: 오늘의 묵상 목록
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meditation.dart';

/**
 * MeditationService 클래스
 * 
 * Firestore와 상호작용하여 묵상 데이터를 관리
 * 싱글톤 패턴으로 구현되어 앱 전체에서 하나의 인스턴스만 사용
 */
class MeditationService {
  // ========== Singleton 패턴 구현 ==========
  
  /// Singleton 인스턴스
  static final MeditationService _instance = MeditationService._internal();
  
  /// Factory 생성자 - 항상 같은 인스턴스 반환
  factory MeditationService() => _instance;
  
  /// Private 생성자
  MeditationService._internal();

  // ========== Firestore 인스턴스 ==========
  
  /// Firestore 데이터베이스 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 메모리 캐시: userId별로 묵상 목록 저장
  /// 네트워크 요청 횟수를 줄여 성능 향상
  /// 
  /// 구조: {
  ///   'user123': [Meditation1, Meditation2, ...],
  ///   'user456': [Meditation3, Meditation4, ...]
  /// }
  final Map<String, List<Meditation>> _meditationsCache = {};

  // ========== Firestore 컬렉션 참조 ==========

  /**
   * 특정 사용자의 묵상 컬렉션 참조 가져오기
   * 
   * Firestore 경로: /users/{userId}/meditations
   * 
   * @param userId 사용자 ID
   * @return 묵상 컬렉션 참조
   * 
   * 사용 예:
   * ```dart
   * CollectionReference col = _getUserMeditationsCollection('user123');
   * await col.doc('meditation_456').set(data);
   * ```
   */
  CollectionReference _getUserMeditationsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('meditations');
  }

  // ========== ID 생성 ==========

  /**
   * 고유한 묵상 ID 생성
   * 
   * 형식: "meditation_{현재 밀리초 타임스탬프}"
   * 예: "meditation_1704067200000"
   * 
   * @return 고유 ID 문자열
   * 
   * 특징:
   * - 밀리초 단위 타임스탬프 사용으로 거의 중복 없음
   * - 시간순으로 정렬 가능
   */
  String generateId() {
    return 'meditation_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ========== 조회 메서드 ==========

  /**
   * 사용자의 모든 묵상 가져오기
   * 
   * 동작 순서:
   * 1. Firestore에서 해당 사용자의 모든 묵상 문서 조회
   * 2. 각 문서를 Meditation 객체로 변환
   * 3. 파싱 실패한 문서는 건너뜀
   * 4. 결과를 캐시에 저장
   * 5. Firestore 오류 시 캐시 반환
   * 
   * @param userId 사용자 ID
   * @return 묵상 목록 (비어있을 수 있음)
   * 
   * 사용 위치:
   * - HomeScreen: 전체 묵상 목록 표시
   * - MeditationViewDialog: 묵상 검색 시 사용
   */
  Future<List<Meditation>> getMeditations(String userId) async {
    try {
      print('🔍 Firestore에서 묵상 조회: userId=$userId');

      // Firestore에서 모든 묵상 문서 가져오기
      final snapshot = await _getUserMeditationsCollection(userId).get();

      // 각 문서를 Meditation 객체로 변환
      final meditations = snapshot.docs
          .map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return Meditation.fromJson(data);
        } catch (e) {
          // 파싱 실패한 문서는 null 반환 (나중에 필터링됨)
          print('⚠️ 묵상 파싱 실패: ${doc.id}, $e');
          return null;
        }
      })
          .where((m) => m != null) // null 제거
          .cast<Meditation>() // Meditation? → Meditation 타입 변환
          .toList();

      print('✅ 묵상 ${meditations.length}개 로드됨');

      // 캐시 업데이트 (다음 번에 빠르게 접근 가능)
      _meditationsCache[userId] = meditations;
      return meditations;
    } catch (e) {
      print('❌ Firestore 묵상 조회 실패: $e');
      
      // 네트워크 오류 시 캐시가 있으면 캐시 반환
      if (_meditationsCache.containsKey(userId)) {
        print('⚠️ 캐시에서 반환');
        return _meditationsCache[userId]!;
      }
      
      // 캐시도 없으면 빈 리스트 반환
      return [];
    }
  }

  /**
   * 특정 성경 구절과 관련된 묵상들 가져오기
   * 
   * 동작:
   * 1. 사용자의 모든 묵상 가져오기
   * 2. verses 필드에서 해당 구절이 포함된 묵상만 필터링
   * 3. 최신순으로 정렬 (createdAt 내림차순)
   * 
   * @param userId 사용자 ID
   * @param book 책 이름 (예: "창세기")
   * @param chapter 장 번호
   * @param verse 절 번호
   * @return 해당 구절의 묵상 목록 (최신순)
   * 
   * 사용 위치:
   * - BiblePage: 구절 클릭 시 관련 묵상 표시
   * - MeditationViewDialog: 구절별 묵상 검색
   */
  Future<List<Meditation>> getMeditationsByVerse(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    try {
      print('🔍 구절별 묵상 조회: $book $chapter:$verse');

      // 전체 묵상을 가져와서 메모리에서 필터링
      // (Firestore 복합 쿼리보다 안정적이고 유연함)
      final allMeditations = await getMeditations(userId);

      // verses 배열에서 해당 구절이 있는지 확인
      final filtered = allMeditations.where((meditation) {
        return meditation.verses.any((v) =>
        v.book == book && v.chapter == chapter && v.verse == verse);
      }).toList();

      // 최신순 정렬 (최근 작성한 묵상이 먼저)
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ 해당 구절 묵상 ${filtered.length}개 발견');
      return filtered;
    } catch (e) {
      print('❌ 구절별 묵상 조회 실패: $e');
      return [];
    }
  }

  // ========== 저장 메서드 ==========

  /**
   * 묵상 저장 (신규 생성 또는 수정)
   * 
   * 동작:
   * 1. Firestore에 문서 저장 (set 메서드 사용)
   * 2. 캐시 업데이트 (기존 묵상 수정 또는 새 묵상 추가)
   * 
   * 참고:
   * - set() 메서드는 문서가 없으면 생성, 있으면 덮어쓰기
   * - 같은 ID로 저장하면 수정, 새 ID로 저장하면 생성
   * 
   * @param meditation 저장할 묵상 객체
   * @throws Exception Firestore 저장 실패 시
   * 
   * 사용 위치:
   * - MeditationWritingDialog: "저장" 버튼 클릭 시
   */
  Future<void> saveMeditation(Meditation meditation) async {
    try {
      print('💾 Firestore에 묵상 저장: ${meditation.id}');

      // Firestore 문서 참조 생성
      final docRef = _getUserMeditationsCollection(meditation.userId)
          .doc(meditation.id);

      // 묵상 객체를 JSON으로 변환하여 저장
      await docRef.set(meditation.toJson());

      print('✅ 묵상 저장 완료');

      // 캐시 업데이트
      if (_meditationsCache.containsKey(meditation.userId)) {
        final meditations = _meditationsCache[meditation.userId]!;
        final index = meditations.indexWhere((m) => m.id == meditation.id);
        
        if (index >= 0) {
          // 기존 묵상 수정
          meditations[index] = meditation;
        } else {
          // 새 묵상 추가
          meditations.add(meditation);
        }
      }
    } catch (e) {
      print('❌ Firestore 묵상 저장 실패: $e');
      rethrow; // 에러를 호출자에게 전파 (UI에서 처리)
    }
  }

  // ========== 삭제 메서드 ==========

  /**
   * 묵상 삭제
   * 
   * 동작:
   * 1. Firestore에서 문서 삭제
   * 2. 캐시에서도 삭제
   * 
   * @param userId 사용자 ID
   * @param meditationId 삭제할 묵상 ID
   * @throws Exception Firestore 삭제 실패 시
   * 
   * 사용 위치:
   * - MeditationViewDialog: "삭제" 버튼 클릭 시
   */
  Future<void> deleteMeditation(String userId, String meditationId) async {
    try {
      print('🗑️ Firestore에서 묵상 삭제: $meditationId');

      // Firestore 문서 삭제
      await _getUserMeditationsCollection(userId)
          .doc(meditationId)
          .delete();

      print('✅ 묵상 삭제 완료');

      // 캐시에서도 삭제
      if (_meditationsCache.containsKey(userId)) {
        _meditationsCache[userId]!.removeWhere((m) => m.id == meditationId);
      }
    } catch (e) {
      print('❌ Firestore 묵상 삭제 실패: $e');
      rethrow;
    }
  }

  // ========== 유틸리티 메서드 ==========

  /**
   * 특정 구절의 하이라이트 색상 조회
   * 
   * 동작:
   * 1. 해당 구절의 모든 묵상 조회
   * 2. 가장 최근 묵상의 하이라이트 색상 반환
   * 
   * @param userId 사용자 ID
   * @param book 책 이름
   * @param chapter 장 번호
   * @param verse 절 번호
   * @return 하이라이트 색상 이름 ('yellow', 'blue' 등), 없으면 null
   * 
   * 사용 위치:
   * - BiblePage: 구절 표시 시 하이라이트 색상 적용
   */
  Future<String?> getVerseHighlightColor(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    // 해당 구절의 묵상들 조회 (이미 최신순 정렬됨)
    final meditations = await getMeditationsByVerse(userId, book, chapter, verse);

    // 묵상이 없으면 null 반환
    if (meditations.isEmpty) return null;

    // 가장 최근 묵상의 색상 반환
    return meditations.first.highlightColor;
  }

  /**
   * 특정 날짜의 묵상 가져오기
   * 
   * Firestore 쿼리를 사용하여 날짜 범위로 필터링
   * 
   * @param userId 사용자 ID
   * @param date 조회할 날짜 (시간 부분은 무시됨)
   * @return 해당 날짜의 묵상 목록 (최신순)
   * 
   * 쿼리 범위:
   * - startOfDay: date의 00:00:00
   * - endOfDay: date의 23:59:59 (다음 날 00:00:00)
   * 
   * 사용 위치:
   * - HomeScreen: "오늘의 묵상" 표시
   * - DatePickerDialog: 특정 날짜 묵상 조회
   */
  Future<List<Meditation>> getMeditationsByDate(
      String userId,
      DateTime date,
      ) async {
    try {
      // 날짜의 시작 시간 (00:00:00)
      final startOfDay = DateTime(date.year, date.month, date.day);
      
      // 날짜의 끝 시간 (다음 날 00:00:00)
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Firestore 쿼리: createdAt이 startOfDay ~ endOfDay 사이인 문서 조회
      final snapshot = await _getUserMeditationsCollection(userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('createdAt', isLessThan: endOfDay.toIso8601String())
          .get();

      // 문서를 Meditation 객체로 변환
      final meditations = snapshot.docs
          .map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return Meditation.fromJson(data);
        } catch (e) {
          return null;
        }
      })
          .where((m) => m != null)
          .cast<Meditation>()
          .toList();

      // 최신순 정렬
      meditations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return meditations;
    } catch (e) {
      print('❌ 날짜별 묵상 조회 실패: $e');
      return [];
    }
  }

  // ========== 캐시 관리 ==========

  /**
   * 모든 사용자의 캐시 초기화
   * 
   * 사용 시점:
   * - 로그아웃 시
   * - 메모리 정리 필요 시
   * - 강제 새로고침 시
   */
  void clearCache() {
    _meditationsCache.clear();
    print('🗑️ 묵상 캐시 초기화');
  }

  /**
   * 특정 사용자의 캐시만 초기화
   * 
   * @param userId 캐시를 삭제할 사용자 ID
   * 
   * 사용 시점:
   * - 해당 사용자가 로그아웃 시
   * - 해당 사용자 데이터만 새로고침 시
   */
  void clearUserCache(String userId) {
    _meditationsCache.remove(userId);
    print('🗑️ $userId 캐시 초기화');
  }
}
