/**
 * preferences_service.dart
 * 
 * 사용자 설정을 로컬에 저장하고 불러오는 서비스
 * 
 * 역할:
 * - SharedPreferences를 사용하여 앱 설정 영구 저장
 * - 폰트 크기 설정 (제목, 본문)
 * - 번역 설정 (한글/ESV/비교)
 * 
 * 저장 위치:
 * - 웹: localStorage
 * - 모바일: 기기 내부 저장소
 * 
 * 디자인 패턴:
 * - Singleton 패턴 사용 (앱 전체에서 하나의 인스턴스만 존재)
 * 
 * 사용 위치:
 * - main.dart: 앱 시작 시 초기화
 * - SettingsDialog: 설정 변경 시 저장
 * - BiblePage: 저장된 설정 적용
 */

import 'package:shared_preferences/shared_preferences.dart';

/**
 * PreferencesService 클래스
 * 
 * SharedPreferences를 래핑하여 타입 안전한 설정 관리 제공
 * Singleton 패턴으로 구현되어 앱 전체에서 동일한 인스턴스 사용
 */
class PreferencesService {
  // ========== Singleton 패턴 구현 ==========
  
  /// Singleton 인스턴스
  /// _internal() 생성자로 한 번만 생성
  static final PreferencesService _instance = PreferencesService._internal();
  
  /// Factory 생성자
  /// PreferencesService()를 호출하면 항상 같은 인스턴스 반환
  factory PreferencesService() => _instance;
  
  /// Private 생성자
  /// 외부에서 new PreferencesService._internal() 호출 불가
  PreferencesService._internal();

  // ========== SharedPreferences 인스턴스 ==========
  
  /// SharedPreferences 인스턴스
  /// init() 호출 전까지는 null
  SharedPreferences? _prefs;

  // ========== 키 상수 정의 ==========
  // SharedPreferences에 저장할 때 사용하는 키 이름
  // 상수로 정의하여 오타 방지 및 코드 재사용성 향상
  
  /// 제목 폰트 크기 저장 키
  static const String _keyTitleFontSize = 'title_font_size';
  
  /// 본문 폰트 크기 저장 키
  static const String _keyBodyFontSize = 'body_font_size';
  
  /// 번역 설정 저장 키
  static const String _keyTranslation = 'translation';

  // ========== 기본값 정의 ==========
  // 설정이 저장되지 않았을 때 사용할 기본값
  
  /// 제목 기본 폰트 크기 (20.0)
  static const double defaultTitleSize = 20.0;
  
  /// 본문 기본 폰트 크기 (16.0)
  static const double defaultBodySize = 16.0;
  
  /// 번역 기본 설정 (한글)
  /// 'korean', 'esv', 'compare' 중 하나
  static const String defaultTranslation = 'korean';

  // ========== 초기화 ==========
  
  /**
   * SharedPreferences 초기화
   * 
   * 앱 시작 시 main.dart에서 호출
   * 비동기 작업이므로 await 필요
   * 
   * 호출 시점:
   * - main() 함수에서 runApp() 전에 호출
   * 
   * 사용 예:
   * ```dart
   * void main() async {
   *   WidgetsFlutterBinding.ensureInitialized();
   *   await PreferencesService().init();
   *   runApp(MyApp());
   * }
   * ```
   */
  Future<void> init() async {
    // SharedPreferences 인스턴스 가져오기
    // 처음 호출 시 플랫폼별 저장소 초기화
    _prefs = await SharedPreferences.getInstance();
    print('✅ PreferencesService 초기화 완료');
  }

  // ========== 저장 메서드 ==========

  /**
   * 제목 폰트 크기 저장
   * 
   * @param size 저장할 폰트 크기 (권장: 16.0 ~ 32.0)
   * 
   * 사용 위치:
   * - SettingsDialog: 사용자가 슬라이더로 크기 조정 시
   */
  Future<void> saveTitleFontSize(double size) async {
    await _prefs?.setDouble(_keyTitleFontSize, size);
    print('💾 제목 글씨 크기 저장: $size');
  }

  /**
   * 본문 폰트 크기 저장
   * 
   * @param size 저장할 폰트 크기 (권장: 12.0 ~ 24.0)
   * 
   * 사용 위치:
   * - SettingsDialog: 사용자가 슬라이더로 크기 조정 시
   */
  Future<void> saveBodyFontSize(double size) async {
    await _prefs?.setDouble(_keyBodyFontSize, size);
    print('💾 본문 글씨 크기 저장: $size');
  }

  /**
   * 번역 설정 저장
   * 
   * @param translation 번역 설정
   *   - 'korean': 개역개정 한글
   *   - 'esv': English Standard Version
   *   - 'compare': 한글+영어 비교
   * 
   * 사용 위치:
   * - TranslationDialog: 사용자가 번역 선택 시
   */
  Future<void> saveTranslation(String translation) async {
    await _prefs?.setString(_keyTranslation, translation);
    print('💾 역본 저장: $translation');
  }

  // ========== 불러오기 메서드 ==========

  /**
   * 저장된 제목 폰트 크기 불러오기
   * 
   * @return 저장된 폰트 크기, 없으면 기본값(20.0) 반환
   * 
   * 사용 위치:
   * - BiblePage: 화면 렌더링 시 적용
   * - SettingsDialog: 현재 설정값 표시
   */
  double getTitleFontSize() {
    // ?? 연산자: 왼쪽이 null이면 오른쪽 값 사용
    final size = _prefs?.getDouble(_keyTitleFontSize) ?? defaultTitleSize;
    print('📖 제목 글씨 크기 불러오기: $size');
    return size;
  }

  /**
   * 저장된 본문 폰트 크기 불러오기
   * 
   * @return 저장된 폰트 크기, 없으면 기본값(16.0) 반환
   * 
   * 사용 위치:
   * - BiblePage: 화면 렌더링 시 적용
   * - SettingsDialog: 현재 설정값 표시
   */
  double getBodyFontSize() {
    final size = _prefs?.getDouble(_keyBodyFontSize) ?? defaultBodySize;
    print('📖 본문 글씨 크기 불러오기: $size');
    return size;
  }

  /**
   * 저장된 번역 설정 불러오기
   * 
   * @return 저장된 번역 설정, 없으면 기본값('korean') 반환
   * 
   * 사용 위치:
   * - BiblePage: 어떤 번역을 표시할지 결정
   * - TranslationDialog: 현재 선택된 번역 표시
   */
  String getTranslation() {
    final translation = _prefs?.getString(_keyTranslation) ?? defaultTranslation;
    print('📖 역본 불러오기: $translation');
    return translation;
  }

  // ========== 설정 초기화 ==========

  /**
   * 모든 설정을 기본값으로 초기화
   * 
   * 주의:
   * - 저장된 모든 설정이 삭제됨
   * - 다음 번 앱 실행 시 기본값으로 시작
   * 
   * 사용 위치:
   * - SettingsDialog: "설정 초기화" 버튼
   * - 디버깅 또는 테스트 용도
   */
  Future<void> resetAll() async {
    // 각 키에 해당하는 값 삭제
    await _prefs?.remove(_keyTitleFontSize);
    await _prefs?.remove(_keyBodyFontSize);
    await _prefs?.remove(_keyTranslation);
    print('🔄 모든 설정 초기화');
  }
}
