/**
 * auth_service.dart
 * 
 * 사용자 인증(로그인/로그아웃)을 담당하는 서비스
 * 
 * 역할:
 * - Google 소셜 로그인
 * - Kakao 소셜 로그인 (웹 전용)
 * - 로그인 상태 관리 및 모니터링
 * - 사용자 정보 조회
 * 
 * 지원 로그인 방식:
 * 1. Google 로그인: Firebase Authentication 직접 연동
 * 2. Kakao 로그인: JavaScript SDK → Firebase 익명 인증
 * 
 * 특별한 구현 사항:
 * - Kakao는 Firebase 익명 인증을 활용하여 일관된 userId 유지
 * - JavaScript Promise를 Dart Future로 변환하여 사용
 * - SharedPreferences로 Kakao ID와 Firebase UID 매핑 저장
 * 
 * 디자인 패턴:
 * - Singleton 패턴
 * 
 * 사용 위치:
 * - LoginScreen: 로그인 버튼 클릭 시
 * - HomeScreen: 로그아웃 버튼 클릭 시
 * - main.dart: 로그인 상태 모니터링
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:js' as js; // JavaScript 상호작용 (웹 전용)
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/**
 * AuthService 클래스
 * 
 * Firebase Authentication과 소셜 로그인 SDK를 관리
 * 싱글톤 패턴으로 구현되어 앱 전체에서 하나의 인스턴스만 사용
 */
class AuthService {
  // ========== Singleton 패턴 구현 ==========
  
  /// Singleton 인스턴스
  static final AuthService _instance = AuthService._internal();
  
  /// Factory 생성자 - 항상 같은 인스턴스 반환
  factory AuthService() => _instance;
  
  /// Private 생성자
  /// 초기화 시 저장된 Kakao 사용자 ID 로드
  AuthService._internal() {
    _loadKakaoUserId();
  }

  // ========== Authentication 인스턴스 ==========
  
  /// Firebase Authentication 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Google Sign-In 인스턴스
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ========== 로그인 상태 관리 ==========
  
  /// 현재 로그인 제공자 ('google', 'kakao', null)
  /// null이면 로그인되지 않은 상태
  String? _loginProvider;
  
  /// Kakao 사용자 ID (Kakao 로그인 시에만 사용)
  /// SharedPreferences에 저장되어 앱 재시작 후에도 유지
  String? _kakaoUserId;

  // ========== Kakao 사용자 ID 관리 ==========

  /**
   * 저장된 Kakao 사용자 ID 로드
   * 
   * 앱 시작 시 자동 호출되어 이전 Kakao 로그인 상태 복원
   * 
   * 동작:
   * 1. SharedPreferences에서 'kakao_user_id' 로드
   * 2. 값이 있으면 _kakaoUserId에 저장
   * 3. _loginProvider를 'kakao'로 설정
   */
  Future<void> _loadKakaoUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _kakaoUserId = prefs.getString('kakao_user_id');
    if (_kakaoUserId != null) {
      _loginProvider = 'kakao';
    }
  }

  /**
   * Kakao 사용자 ID 저장
   * 
   * Kakao 로그인 성공 시 호출
   * 
   * @param kakaoId Kakao에서 받은 사용자 ID
   */
  Future<void> _saveKakaoUserId(String kakaoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kakao_user_id', kakaoId);
    _kakaoUserId = kakaoId;
  }

  /**
   * Kakao 사용자 ID 삭제
   * 
   * Kakao 로그아웃 시 호출
   */
  Future<void> _clearKakaoUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kakao_user_id');
    _kakaoUserId = null;
  }

  // ========== Kakao - Firebase UID 매핑 관리 ==========
  
  /**
   * Kakao ID와 Firebase UID 매핑 저장
   * 
   * 중요: Kakao 로그인은 Firebase 익명 인증을 사용하므로
   * 같은 Kakao 계정이 매번 같은 Firebase UID를 사용하도록
   * 매핑 정보를 저장
   * 
   * @param kakaoId Kakao 사용자 ID
   * @param firebaseUid Firebase Anonymous Auth UID
   * 
   * 저장 키: 'kakao_{kakaoId}_firebase_uid'
   */
  Future<void> _saveKakaoFirebaseUid(String kakaoId, String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kakao_${kakaoId}_firebase_uid', firebaseUid);
  }

  /**
   * Kakao ID에 해당하는 Firebase UID 가져오기
   * 
   * @param kakaoId Kakao 사용자 ID
   * @return 저장된 Firebase UID, 없으면 null
   */
  Future<String?> _getKakaoFirebaseUid(String kakaoId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('kakao_${kakaoId}_firebase_uid');
  }

  // ========== 현재 사용자 정보 ==========

  /**
   * 현재 로그인된 Firebase 사용자 가져오기
   * 
   * @return Firebase User 객체, 로그인되지 않았으면 null
   */
  User? get currentUser => _auth.currentUser;

  /**
   * 로그인 상태 변화 스트림
   * 
   * Firebase Auth의 상태 변화를 실시간으로 구독 가능
   * 
   * @return Stream<User?> - 로그인/로그아웃 시 이벤트 발생
   * 
   * 사용 위치:
   * - main.dart: StreamBuilder로 로그인 상태에 따라 화면 전환
   */
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /**
   * 로그인 여부 확인
   * 
   * @return true: 로그인됨, false: 로그인 안 됨
   * 
   * 참고: _loginProvider가 null이 아니면 로그인된 것으로 간주
   */
  bool get isLoggedIn => _loginProvider != null;

  // ========== Google 로그인 ==========

  /**
   * Google 계정으로 로그인
   * 
   * 동작 순서:
   * 1. Google Sign-In 팝업 표시
   * 2. 사용자가 계정 선택 및 권한 승인
   * 3. Google에서 Access Token과 ID Token 받기
   * 4. Firebase Credential 생성
   * 5. Firebase Authentication 로그인
   * 6. _loginProvider를 'google'로 설정
   * 
   * @return UserCredential (로그인 성공 시), null (취소 또는 실패 시)
   * 
   * 사용 위치:
   * - LoginScreen: "Google로 로그인" 버튼
   */
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Google Sign-In 팝업 표시
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // 사용자가 로그인 취소한 경우
      if (googleUser == null) {
        return null;
      }

      // Google 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Firebase Credential 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Authentication 로그인
      final userCredential = await _auth.signInWithCredential(credential);

      // 로그인 제공자 저장
      _loginProvider = 'google';
      print('✅ Google 로그인 성공: ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      print('❌ Google 로그인 실패: $e');
      return null;
    }
  }

  // ========== Kakao 로그인 ==========

  /**
   * Kakao 계정으로 로그인 (웹 전용)
   * 
   * 동작 순서:
   * 1. JavaScript의 kakaoLogin.login() 함수 호출
   * 2. Kakao SDK 팝업으로 사용자 인증
   * 3. Kakao 사용자 정보 (ID, 닉네임, 프로필 이미지) 받기
   * 4. 이전에 저장된 Firebase UID가 있는지 확인
   * 5. 없으면 새로운 Firebase 익명 계정 생성
   * 6. Firebase 프로필 업데이트 (닉네임, 사진)
   * 7. Kakao ID와 Firebase UID 매핑 저장
   * 
   * 중요 개념:
   * - Kakao는 Firebase Authentication을 지원하지 않음
   * - 대신 Firebase 익명 인증을 사용하고, Kakao ID로 구분
   * - SharedPreferences로 Kakao ID ↔ Firebase UID 매핑 유지
   * 
   * @return UserCredential (성공 시), null (실패 시)
   * 
   * 사용 위치:
   * - LoginScreen: "카카오로 로그인" 버튼
   */
  Future<UserCredential?> signInWithKakao() async {
    try {
      print('🔍 Kakao 로그인 시작...');

      // JavaScript의 kakaoLogin 객체 가져오기
      // (index.html에서 정의된 전역 객체)
      final kakaoLoginObj = js.context['kakaoLogin'];
      print('🔍 kakaoLoginObj: $kakaoLoginObj');

      // kakaoLogin.login() 호출 → JavaScript Promise 반환
      final jsPromise = kakaoLoginObj.callMethod('login');
      print('🔍 jsPromise 호출 완료');

      // Promise를 Dart Future로 변환
      final result = await _promiseToFuture(jsPromise);
      print('🔍 Promise 결과: $result');

      // 사용자가 로그인 취소한 경우
      if (result == null) {
        print('❌ Kakao 로그인 취소');
        return null;
      }

      // JavaScript 객체에서 사용자 정보 추출
      final jsUserInfo = result as js.JsObject;
      print('🔍 jsUserInfo type: ${jsUserInfo.runtimeType}');
      print('🔍 jsUserInfo: $jsUserInfo');

      final kakaoId = jsUserInfo['id'].toString();
      print('🔍 Extracted Kakao ID: $kakaoId');

      final nickname = jsUserInfo['nickname'].toString();
      print('🔍 Extracted nickname: $nickname');

      final profileImage = jsUserInfo['profileImage'].toString();
      print('🔍 Extracted profileImage: $profileImage');

      print('✅ Kakao 사용자 정보: ID=$kakaoId, 닉네임=$nickname');

      // 이 Kakao ID로 이전에 생성한 Firebase UID가 있는지 확인
      final savedFirebaseUid = await _getKakaoFirebaseUid(kakaoId);

      UserCredential? userCredential;

      if (savedFirebaseUid != null) {
        // ===== 이전에 로그인한 적이 있는 Kakao 계정 =====
        print('📝 저장된 Firebase UID 발견: $savedFirebaseUid');

        // 현재 Firebase 로그인 상태 확인
        final currentUser = _auth.currentUser;

        if (currentUser != null && currentUser.uid == savedFirebaseUid) {
          // 이미 같은 Firebase 계정으로 로그인되어 있음
          print('✅ 기존 Firebase 계정 재사용: ${currentUser.uid}');

          // 프로필만 업데이트 (닉네임이나 사진이 바뀌었을 수 있음)
          await currentUser.updateDisplayName(nickname);
          if (profileImage.isNotEmpty) {
            await currentUser.updatePhotoURL(profileImage);
          }

          // UserCredential 없이 진행
          _loginProvider = 'kakao';
          await _saveKakaoUserId(kakaoId);
          print('✅ Kakao 로그인 성공: $nickname (Kakao ID: $kakaoId, Firebase UID: ${currentUser.uid})');

          // 더미 UserCredential 반환 (실제로는 사용되지 않음)
          return await _auth.signInAnonymously();
        } else {
          // 저장된 UID는 있지만 현재 로그인 안 되어 있음
          // 새로운 익명 계정 생성
          print('⚠️ 저장된 UID와 다른 상태 - 새 계정 생성');
          userCredential = await _auth.signInAnonymously();

          // 새 UID를 저장
          await _saveKakaoFirebaseUid(kakaoId, userCredential.user!.uid);
          print('💾 새 Firebase UID 저장: ${userCredential.user!.uid}');
        }
      } else {
        // ===== 처음 로그인하는 Kakao 계정 =====
        print('🆕 새로운 Kakao 계정 - Firebase 계정 생성');
        
        // Firebase 익명 인증으로 새 계정 생성
        userCredential = await _auth.signInAnonymously();

        // Kakao ID ↔ Firebase UID 매핑 저장
        await _saveKakaoFirebaseUid(kakaoId, userCredential.user!.uid);
        print('💾 Firebase UID 저장: ${userCredential.user!.uid}');
      }

      // Firebase 프로필 업데이트 (닉네임, 프로필 사진)
      await userCredential?.user?.updateDisplayName(nickname);
      if (profileImage.isNotEmpty) {
        await userCredential?.user?.updatePhotoURL(profileImage);
      }

      // 로그인 제공자 및 Kakao ID 저장
      _loginProvider = 'kakao';
      await _saveKakaoUserId(kakaoId);
      print('✅ Kakao 로그인 성공: $nickname (Kakao ID: $kakaoId, Firebase UID: ${userCredential?.user?.uid})');
      return userCredential;
    } catch (e) {
      print('❌ Kakao 로그인 실패: $e');
      return null;
    }
  }

  // ========== JavaScript Promise 변환 ==========

  /**
   * JavaScript Promise를 Dart Future로 변환
   * 
   * 웹 환경에서 JavaScript와 Dart가 상호작용할 때 필요
   * JavaScript의 비동기 작업 결과를 Dart에서 await 가능하게 만듦
   * 
   * @param jsPromise JavaScript Promise 객체
   * @return Dart Future<dynamic>
   * 
   * 동작:
   * 1. Completer 생성 (Future를 수동으로 완료시키기 위해)
   * 2. Promise.then() 콜백 등록 → 성공 시 Completer 완료
   * 3. Promise.catch() 콜백 등록 → 실패 시 Completer 에러 완료
   * 4. Completer.future 반환
   */
  Future<dynamic> _promiseToFuture(js.JsObject jsPromise) async {
    final completer = Completer<dynamic>();

    // Promise.then() - 성공 콜백
    jsPromise.callMethod('then', [
          (value) {
        completer.complete(value);
      }
    ]);

    // Promise.catch() - 실패 콜백
    jsPromise.callMethod('catch', [
          (error) {
        completer.completeError(error);
      }
    ]);

    return completer.future;
  }

  // ========== 로그아웃 ==========

  /**
   * 로그아웃 처리
   * 
   * 동작:
   * 1. 로그인 제공자에 따라 적절한 로그아웃 메서드 호출
   * 2. Google: Firebase + Google Sign-In 모두 로그아웃
   * 3. Kakao: JavaScript SDK 로그아웃만 수행 (Firebase 세션은 유지)
   * 4. _loginProvider와 _kakaoUserId 초기화
   * 
   * 중요:
   * - Kakao는 Firebase 익명 계정을 그대로 유지
   * - 이렇게 하면 다음 로그인 시 같은 UID 재사용 가능
   * - 묵상 데이터 등이 유지됨
   * 
   * 사용 위치:
   * - HomeScreen: "로그아웃" 버튼
   */
  Future<void> signOut() async {
    try {
      final futures = <Future>[];

      if (_loginProvider == 'google') {
        // Google 로그아웃: Sign-In SDK와 Firebase 모두 로그아웃
        futures.add(_googleSignIn.signOut());
        futures.add(_auth.signOut());
      }

      if (_loginProvider == 'kakao') {
        // Kakao JavaScript SDK 로그아웃
        try {
          final jsPromise = js.context.callMethod('kakaoLogout');
          await _promiseToFuture(jsPromise);
        } catch (e) {
          print('Kakao 로그아웃 오류 (무시): $e');
        }
        
        // ⚠️ 중요: Firebase는 로그아웃하지 않음
        // 익명 계정을 유지하여 다음 로그인 시 같은 UID 사용
      }

      // 모든 비동기 작업 완료 대기
      await Future.wait(futures);
      
      // 로그인 상태 초기화
      _loginProvider = null;
      await _clearKakaoUserId();
      
      print('✅ 로그아웃 완료 ${_loginProvider == 'kakao' ? '(Firebase 세션 유지)' : ''}');
    } catch (e) {
      print('❌ 로그아웃 실패: $e');
    }
  }

  // ========== 사용자 정보 조회 ==========

  /**
   * 사용자 이름 가져오기
   * 
   * @return 사용자 이름 (displayName), 없으면 null
   */
  String? getUserName() => _auth.currentUser?.displayName;
  
  /**
   * 사용자 이메일 가져오기
   * 
   * @return 이메일 주소, 없으면 null
   * 
   * 참고: Kakao 로그인은 익명 인증이므로 이메일 없음
   */
  String? getUserEmail() => _auth.currentUser?.email;
  
  /**
   * 사용자 프로필 사진 URL 가져오기
   * 
   * @return 프로필 사진 URL, 없으면 null
   */
  String? getUserPhoto() => _auth.currentUser?.photoURL;

  /**
   * 일관된 사용자 ID 반환
   * 
   * Firestore 문서 경로 등에 사용할 고유 ID
   * 
   * @return 사용자 ID 문자열
   * 
   * 규칙:
   * - Kakao 로그인: 'kakao_{kakaoId}' 형식
   * - Google 로그인: Firebase UID 그대로
   * 
   * 이렇게 하는 이유:
   * - Kakao는 Firebase 익명 인증을 사용하므로 UID가 변할 수 있음
   * - Kakao ID를 사용하면 항상 일관된 ID 보장
   */
  String? getUserId() {
    if (_loginProvider == 'kakao' && _kakaoUserId != null) {
      // Kakao 로그인: 'kakao_' 접두사 + Kakao ID
      return 'kakao_$_kakaoUserId';
    } else {
      // Google 로그인: Firebase UID 사용
      return _auth.currentUser?.uid;
    }
  }

  /**
   * 현재 로그인 제공자 가져오기
   * 
   * @return 'google', 'kakao', null
   */
  String? getLoginProvider() => _loginProvider;
}
