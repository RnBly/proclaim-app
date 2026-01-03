/**
 * firebase_config.dart
 * 
 * Firebase 프로젝트 설정 정보를 담고 있는 파일
 * 
 * 역할:
 * - Firebase 프로젝트 연결에 필요한 인증 정보 제공
 * - main.dart에서 Firebase.initializeApp() 호출 시 사용
 * 
 * 주의사항:
 * - 이 파일은 민감한 정보를 포함하므로 공개 저장소에 업로드 시 주의 필요
 * - 플랫폼별로 다른 설정이 필요한 경우 조건부 import 사용 가능
 */

import 'package:firebase_core/firebase_core.dart';

/**
 * FirebaseConfig 클래스
 * 
 * Firebase 초기화에 필요한 설정값을 static const로 제공
 * 웹 플랫폼용 Firebase 설정
 */
class FirebaseConfig {
  /**
   * Firebase 프로젝트 설정
   * 
   * Firebase Console (https://console.firebase.google.com)에서 발급받은 값
   * - apiKey: Web API 키 (웹 클라이언트 인증용)
   * - authDomain: Firebase Authentication 도메인
   * - projectId: Firebase 프로젝트 고유 ID
   * - storageBucket: Cloud Storage 버킷 주소
   * - messagingSenderId: FCM(Firebase Cloud Messaging) 발신자 ID
   * - appId: Firebase 앱 고유 ID
   * - measurementId: Google Analytics 측정 ID (선택사항)
   */
  static const firebaseConfig = FirebaseOptions(
      apiKey: "AIzaSyDl-MCB6udMyGtm6BnwZ9H9zfAL7b1vD2M",
      authDomain: "proclaim-479112.firebaseapp.com",
      projectId: "proclaim-479112",
      storageBucket: "proclaim-479112.firebasestorage.app",
      messagingSenderId: "489632599986",
      appId: "1:489632599986:web:262d6d0987431ba2879eab",
      measurementId: "G-NP82185RPX"
  );
}
