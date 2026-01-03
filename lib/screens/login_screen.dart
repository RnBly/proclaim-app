/**
 * login_screen.dart
 * 
 * 사용자 로그인 화면
 * 
 * 역할:
 * - Google 소셜 로그인 제공
 * - Kakao 소셜 로그인 제공
 * - 로그인 없이 사용 옵션 제공 ("나중에 하기")
 * 
 * UI 구성:
 * - 그라데이션 배경 (주황색 계열)
 * - Shofar 로고
 * - 로그인 안내 카드
 * - Google 로그인 버튼 (흰색)
 * - Kakao 로그인 버튼 (노란색)
 * - "나중에 하기" 텍스트 버튼
 * 
 * 로그인 흐름:
 * 1. 사용자가 로그인 버튼 클릭
 * 2. _isLoading = true → 로딩 인디케이터 표시
 * 3. AuthService 호출하여 로그인 처리
 * 4. 성공 시 → 홈 화면으로 이동
 * 5. 실패 시 → 스낵바로 오류 메시지 표시
 * 
 * 사용 위치:
 * - main.dart: 로그인되지 않은 상태에서 표시
 * - "나중에 하기" 클릭 시 로그인 없이 앱 사용 가능
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/**
 * LoginScreen 위젯
 * 
 * StatefulWidget으로 로딩 상태 관리
 */
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/**
 * _LoginScreenState
 * 
 * 로그인 화면의 상태 및 로그인 처리 로직 관리
 */
class _LoginScreenState extends State<LoginScreen> {
  /// AuthService 인스턴스 (Singleton)
  final AuthService _authService = AuthService();
  
  /// 로딩 상태 플래그
  /// true: 로그인 중 (로딩 인디케이터 표시)
  /// false: 대기 중 (로그인 버튼 표시)
  bool _isLoading = false;

  /**
   * Google 로그인 처리
   * 
   * 동작 순서:
   * 1. 로딩 상태 시작
   * 2. AuthService.signInWithGoogle() 호출
   * 3. 위젯이 아직 마운트되어 있는지 확인 (비동기 작업 후 필수)
   * 4. 로딩 상태 종료
   * 5. 결과에 따라 화면 이동 또는 오류 메시지 표시
   * 
   * mounted 체크:
   * - 비동기 작업 후 setState 호출 전 반드시 확인
   * - 위젯이 dispose된 후 setState 호출하면 오류 발생
   */
  Future<void> _handleGoogleSignIn() async {
    // 로딩 상태 시작
    setState(() => _isLoading = true);

    // Google 로그인 시도
    final userCredential = await _authService.signInWithGoogle();

    // 비동기 작업 후 위젯이 아직 화면에 있는지 확인
    if (!mounted) return;

    // 로딩 상태 종료
    setState(() => _isLoading = false);

    if (userCredential != null) {
      // ===== 로그인 성공 =====
      // 홈 화면으로 이동 (뒤로 가기 불가)
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // ===== 로그인 실패 또는 취소 =====
      // 스낵바로 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 취소되었거나 실패했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /**
   * Kakao 로그인 처리
   * 
   * Google 로그인과 동일한 흐름
   * AuthService.signInWithKakao() 호출
   */
  Future<void> _handleKakaoSignIn() async {
    // 로딩 상태 시작
    setState(() => _isLoading = true);

    // Kakao 로그인 시도
    final userCredential = await _authService.signInWithKakao();

    // 비동기 작업 후 위젯이 아직 화면에 있는지 확인
    if (!mounted) return;

    // 로딩 상태 종료
    setState(() => _isLoading = false);

    if (userCredential != null) {
      // ===== 로그인 성공 =====
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // ===== 로그인 실패 또는 취소 =====
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카카오 로그인이 취소되었거나 실패했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 배경: 그라데이션 (주황색 계열)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFCE6E26), // Proclaim 메인 컬러 (진한 주황)
              Color(0xFFE88D4F), // 밝은 주황
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ========== 앱 로고 (Shofar) ==========
                  Image.asset(
                    'assets/images/shofar_logo.png',
                    width: 180,
                    height: 180,
                  ),

                  const SizedBox(height: 40),

                  // ========== 로그인 안내 카드 ==========
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // --- 안내 텍스트 ---
                        const Text(
                          '개인 묵상 노트를 저장하려면',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '로그인이 필요합니다',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // --- 로딩 인디케이터 또는 로그인 버튼 ---
                        _isLoading
                            ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFCE6E26),
                          ),
                        )
                            : Column(
                          children: [
                            // ========== Google 로그인 버튼 ==========
                            /*
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                  side: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Google로 로그인',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
*/
                            // ========== Kakao 로그인 버튼 ==========
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _handleKakaoSignIn,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.black87,
                                  backgroundColor: const Color(0xFFFEE500), // 카카오 공식 노란색
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  '카카오로 로그인',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // --- 로그인 이점 설명 ---
                        Text(
                          '로그인하면 여러 기기에서\n나의 묵상 노트를 확인할 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ========== "나중에 하기" 버튼 ==========
                  // 로그인 없이 앱 사용 가능
                  // 묵상 기능은 사용 불가, 읽기 기능만 사용 가능
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/home');
                    },
                    child: const Text(
                      '나중에 하기',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
