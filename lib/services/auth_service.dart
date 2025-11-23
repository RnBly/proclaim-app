import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:js' as js;
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // 싱글톤 패턴
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _loadKakaoUserId();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 로그인 제공자 추적
  String? _loginProvider;
  String? _kakaoUserId; // Kakao 사용자 ID 저장

  // Kakao 사용자 ID 로드
  Future<void> _loadKakaoUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _kakaoUserId = prefs.getString('kakao_user_id');
    if (_kakaoUserId != null) {
      _loginProvider = 'kakao';
    }
  }

  // Kakao 사용자 ID 저장
  Future<void> _saveKakaoUserId(String kakaoId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kakao_user_id', kakaoId);
    _kakaoUserId = kakaoId;
  }

  // Kakao 사용자 ID 삭제
  Future<void> _clearKakaoUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('kakao_user_id');
    _kakaoUserId = null;
  }

  // Kakao ID별 Firebase UID 저장
  Future<void> _saveKakaoFirebaseUid(String kakaoId, String firebaseUid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kakao_${kakaoId}_firebase_uid', firebaseUid);
  }

  // Kakao ID별 Firebase UID 가져오기
  Future<String?> _getKakaoFirebaseUid(String kakaoId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('kakao_${kakaoId}_firebase_uid');
  }

  // 현재 로그인된 사용자 가져오기
  User? get currentUser => _auth.currentUser;

  // 로그인 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 로그인 여부 확인
  bool get isLoggedIn => _loginProvider != null;

  // Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      _loginProvider = 'google';
      print('✅ Google 로그인 성공: ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      print('❌ Google 로그인 실패: $e');
      return null;
    }
  }

  // Kakao 로그인 (JavaScript 호출)
  Future<UserCredential?> signInWithKakao() async {
    try {
      print('🔍 Kakao 로그인 시작...');

      // JavaScript의 kakaoLogin.login 함수 호출
      final kakaoLoginObj = js.context['kakaoLogin'];
      print('🔍 kakaoLoginObj: $kakaoLoginObj');

      final jsPromise = kakaoLoginObj.callMethod('login');
      print('🔍 jsPromise 호출 완료');

      // Promise를 Future로 변환
      final result = await _promiseToFuture(jsPromise);
      print('🔍 Promise 결과: $result');

      if (result == null) {
        print('❌ Kakao 로그인 취소');
        return null;
      }

      // 사용자 데이터 파싱 (이미 객체로 반환됨)
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
        // 이전에 생성한 Firebase UID가 있음
        print('📝 저장된 Firebase UID 발견: $savedFirebaseUid');

        // 현재 로그인되어 있는지 확인
        final currentUser = _auth.currentUser;

        if (currentUser != null && currentUser.uid == savedFirebaseUid) {
          // 이미 같은 계정으로 로그인되어 있음 - 프로필만 업데이트
          print('✅ 기존 Firebase 계정 재사용: ${currentUser.uid}');

          // 프로필 업데이트
          await currentUser.updateDisplayName(nickname);
          if (profileImage.isNotEmpty) {
            await currentUser.updatePhotoURL(profileImage);
          }

          // UserCredential 없이 진행 (이미 로그인되어 있음)
          _loginProvider = 'kakao';
          await _saveKakaoUserId(kakaoId);
          print('✅ Kakao 로그인 성공: $nickname (Kakao ID: $kakaoId, Firebase UID: ${currentUser.uid})');

          // 더미 UserCredential 반환 (사용되지 않음)
          return await _auth.signInAnonymously();
        } else {
          // 저장된 UID는 있지만 로그인 안 되어 있음
          print('⚠️ 저장된 UID와 다른 상태 - 새 계정 생성');
          userCredential = await _auth.signInAnonymously();

          // 새 UID를 저장
          await _saveKakaoFirebaseUid(kakaoId, userCredential.user!.uid);
          print('💾 새 Firebase UID 저장: ${userCredential.user!.uid}');
        }
      } else {
        // 처음 로그인하는 Kakao 계정
        print('🆕 새로운 Kakao 계정 - Firebase 계정 생성');
        userCredential = await _auth.signInAnonymously();

        // UID 저장
        await _saveKakaoFirebaseUid(kakaoId, userCredential.user!.uid);
        print('💾 Firebase UID 저장: ${userCredential.user!.uid}');
      }

      // 프로필 업데이트
      await userCredential?.user?.updateDisplayName(nickname);
      if (profileImage.isNotEmpty) {
        await userCredential?.user?.updatePhotoURL(profileImage);
      }

      _loginProvider = 'kakao';
      await _saveKakaoUserId(kakaoId);
      print('✅ Kakao 로그인 성공: $nickname (Kakao ID: $kakaoId, Firebase UID: ${userCredential?.user?.uid})');
      return userCredential;
    } catch (e) {
      print('❌ Kakao 로그인 실패: $e');
      return null;
    }
  }

  // JavaScript Promise를 Dart Future로 변환
  Future<dynamic> _promiseToFuture(js.JsObject jsPromise) async {
    final completer = Completer<dynamic>();

    jsPromise.callMethod('then', [
          (value) {
        completer.complete(value);
      }
    ]);

    jsPromise.callMethod('catch', [
          (error) {
        completer.completeError(error);
      }
    ]);

    return completer.future;
  }

  // 로그아웃
  Future<void> signOut() async {
    try {
      final futures = <Future>[];

      if (_loginProvider == 'google') {
        futures.add(_googleSignIn.signOut());
        // Google은 Firebase도 로그아웃
        futures.add(_auth.signOut());
      }

      if (_loginProvider == 'kakao') {
        try {
          final jsPromise = js.context.callMethod('kakaoLogout');
          await _promiseToFuture(jsPromise);
        } catch (e) {
          print('Kakao 로그아웃 오류 (무시): $e');
        }
        // ⚠️ Kakao는 Firebase 로그아웃 하지 않음 (익명 계정 유지)
        // 이렇게 하면 다음 로그인 시 같은 계정 재사용 가능
      }

      await Future.wait(futures);
      _loginProvider = null;
      await _clearKakaoUserId();
      print('✅ 로그아웃 완료 ${_loginProvider == 'kakao' ? '(Firebase 세션 유지)' : ''}');
    } catch (e) {
      print('❌ 로그아웃 실패: $e');
    }
  }

  // 사용자 정보 가져오기
  String? getUserName() => _auth.currentUser?.displayName;
  String? getUserEmail() => _auth.currentUser?.email;
  String? getUserPhoto() => _auth.currentUser?.photoURL;

  // 일관된 사용자 ID 반환
  String? getUserId() {
    if (_loginProvider == 'kakao' && _kakaoUserId != null) {
      // Kakao 로그인: 카카오 ID 사용 (일관성 유지)
      return 'kakao_$_kakaoUserId';
    } else {
      // Google 로그인: Firebase UID 사용
      return _auth.currentUser?.uid;
    }
  }

  String? getLoginProvider() => _loginProvider;
}