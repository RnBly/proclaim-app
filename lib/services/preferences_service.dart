import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  // 싱글톤 패턴
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // 키 상수
  static const String _keyTitleFontSize = 'title_font_size';
  static const String _keyBodyFontSize = 'body_font_size';
  static const String _keyTranslation = 'translation';

  // 기본값
  static const double defaultTitleSize = 20.0;
  static const double defaultBodySize = 16.0;
  static const String defaultTranslation = 'korean';

  // 초기화
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ PreferencesService 초기화 완료');
  }

  // 제목 글씨 크기 저장
  Future<void> saveTitleFontSize(double size) async {
    await _prefs?.setDouble(_keyTitleFontSize, size);
    print('💾 제목 글씨 크기 저장: $size');
  }

  // 본문 글씨 크기 저장
  Future<void> saveBodyFontSize(double size) async {
    await _prefs?.setDouble(_keyBodyFontSize, size);
    print('💾 본문 글씨 크기 저장: $size');
  }

  // 역본 저장
  Future<void> saveTranslation(String translation) async {
    await _prefs?.setString(_keyTranslation, translation);
    print('💾 역본 저장: $translation');
  }

  // 제목 글씨 크기 불러오기
  double getTitleFontSize() {
    final size = _prefs?.getDouble(_keyTitleFontSize) ?? defaultTitleSize;
    print('📖 제목 글씨 크기 불러오기: $size');
    return size;
  }

  // 본문 글씨 크기 불러오기
  double getBodyFontSize() {
    final size = _prefs?.getDouble(_keyBodyFontSize) ?? defaultBodySize;
    print('📖 본문 글씨 크기 불러오기: $size');
    return size;
  }

  // 역본 불러오기
  String getTranslation() {
    final translation = _prefs?.getString(_keyTranslation) ?? defaultTranslation;
    print('📖 역본 불러오기: $translation');
    return translation;
  }

  // 모든 설정 초기화
  Future<void> resetAll() async {
    await _prefs?.remove(_keyTitleFontSize);
    await _prefs?.remove(_keyBodyFontSize);
    await _prefs?.remove(_keyTranslation);
    print('🔄 모든 설정 초기화');
  }
}