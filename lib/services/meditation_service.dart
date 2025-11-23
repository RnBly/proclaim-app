import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meditation.dart';

class MeditationService {
  // 싱글톤 패턴
  static final MeditationService _instance = MeditationService._internal();
  factory MeditationService() => _instance;
  MeditationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, List<Meditation>> _meditationsCache = {}; // userId별 캐시

  // Firestore 컬렉션 참조
  CollectionReference _getUserMeditationsCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('meditations');
  }

  // 고유 ID 생성
  String generateId() {
    return 'meditation_${DateTime.now().millisecondsSinceEpoch}';
  }

  // 사용자의 모든 묵상 가져오기
  Future<List<Meditation>> getMeditations(String userId) async {
    try {
      print('🔍 Firestore에서 묵상 조회: userId=$userId');

      final snapshot = await _getUserMeditationsCollection(userId).get();

      final meditations = snapshot.docs
          .map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          return Meditation.fromJson(data);
        } catch (e) {
          print('⚠️ 묵상 파싱 실패: ${doc.id}, $e');
          return null;
        }
      })
          .where((m) => m != null)
          .cast<Meditation>()
          .toList();

      print('✅ 묵상 ${meditations.length}개 로드됨');

      // 캐시 업데이트
      _meditationsCache[userId] = meditations;
      return meditations;
    } catch (e) {
      print('❌ Firestore 묵상 조회 실패: $e');
      // 캐시가 있으면 캐시 반환
      if (_meditationsCache.containsKey(userId)) {
        print('⚠️ 캐시에서 반환');
        return _meditationsCache[userId]!;
      }
      return [];
    }
  }

  // 특정 구절의 묵상들 가져오기
  Future<List<Meditation>> getMeditationsByVerse(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    try {
      print('🔍 구절별 묵상 조회: $book $chapter:$verse');

      // 전체 묵상을 가져와서 필터링 (더 안정적)
      final allMeditations = await getMeditations(userId);

      final filtered = allMeditations.where((meditation) {
        return meditation.verses.any((v) =>
        v.book == book && v.chapter == chapter && v.verse == verse);
      }).toList();

      // 최신순 정렬
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      print('✅ 해당 구절 묵상 ${filtered.length}개 발견');
      return filtered;
    } catch (e) {
      print('❌ 구절별 묵상 조회 실패: $e');
      return [];
    }
  }

  // 묵상 저장
  Future<void> saveMeditation(Meditation meditation) async {
    try {
      print('💾 Firestore에 묵상 저장: ${meditation.id}');

      final docRef = _getUserMeditationsCollection(meditation.userId)
          .doc(meditation.id);

      await docRef.set(meditation.toJson());

      print('✅ 묵상 저장 완료');

      // 캐시 업데이트
      if (_meditationsCache.containsKey(meditation.userId)) {
        final meditations = _meditationsCache[meditation.userId]!;
        final index = meditations.indexWhere((m) => m.id == meditation.id);
        if (index >= 0) {
          meditations[index] = meditation;
        } else {
          meditations.add(meditation);
        }
      }
    } catch (e) {
      print('❌ Firestore 묵상 저장 실패: $e');
      rethrow;
    }
  }

  // 묵상 삭제
  Future<void> deleteMeditation(String userId, String meditationId) async {
    try {
      print('🗑️ Firestore에서 묵상 삭제: $meditationId');

      await _getUserMeditationsCollection(userId)
          .doc(meditationId)
          .delete();

      print('✅ 묵상 삭제 완료');

      // 캐시 업데이트
      if (_meditationsCache.containsKey(userId)) {
        _meditationsCache[userId]!.removeWhere((m) => m.id == meditationId);
      }
    } catch (e) {
      print('❌ Firestore 묵상 삭제 실패: $e');
      rethrow;
    }
  }

  // 특정 구절이 하이라이트되어 있는지 확인
  Future<String?> getVerseHighlightColor(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    final meditations = await getMeditationsByVerse(userId, book, chapter, verse);

    if (meditations.isEmpty) return null;

    // 가장 최근 묵상의 색상 반환
    return meditations.first.highlightColor;
  }

  // 특정 날짜의 묵상 가져오기
  Future<List<Meditation>> getMeditationsByDate(
      String userId,
      DateTime date,
      ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _getUserMeditationsCollection(userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('createdAt', isLessThan: endOfDay.toIso8601String())
          .get();

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

      meditations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return meditations;
    } catch (e) {
      print('❌ 날짜별 묵상 조회 실패: $e');
      return [];
    }
  }

  // 캐시 초기화
  void clearCache() {
    _meditationsCache.clear();
    print('🗑️ 묵상 캐시 초기화');
  }

  // 특정 사용자 캐시 초기화
  void clearUserCache(String userId) {
    _meditationsCache.remove(userId);
    print('🗑️ $userId 캐시 초기화');
  }
}
