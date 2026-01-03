/**
 * kakao_config.dart
 * 
 * 카카오 소셜 로그인에 필요한 앱 키 정보를 담고 있는 파일
 * 
 * 역할:
 * - 카카오 개발자 콘솔에서 발급받은 앱 키 제공
 * - 카카오 로그인 SDK 초기화 시 사용
 * 
 * 주의사항:
 * - 앱 키는 민감한 정보이므로 공개 저장소 업로드 시 주의
 * - JavaScript Key는 웹 플랫폼에서 사용
 * - Native App Key는 Android/iOS 플랫폼에서 사용
 * 
 * 관련 문서:
 * - https://developers.kakao.com/
 */

/**
 * KakaoConfig 클래스
 * 
 * 카카오 로그인에 필요한 API 키를 static const로 제공
 */
class KakaoConfig {
  /**
   * Native App Key (네이티브 앱 키)
   * 
   * 용도: Android, iOS 앱에서 카카오 SDK 초기화 시 사용
   * 발급: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키
   */
  static const String nativeAppKey = '31a551138caadd185a96a2c5c25fb016';
  
  /**
   * JavaScript Key (자바스크립트 키)
   * 
   * 용도: 웹 플랫폼에서 카카오 SDK 초기화 시 사용
   * 발급: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 키
   */
  static const String javascriptKey = 'be5044a082e1ea0952a49969b679cb97';
}
