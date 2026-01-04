/**
 * main.dart
 * 
 * Proclaim 앱의 진입점(Entry Point) 파일
 * 
 * 주요 역할:
 * - Firebase 초기화
 * - SharedPreferences 초기화
 * - BibleService 초기화 (성경 데이터 로딩)
 * - 앱 전역 설정 및 테마 정의
 * - 로그인 상태에 따른 화면 라우팅
 * - 스플래시 스크린 애니메이션 처리
 */

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/bible_service.dart';
import 'services/auth_service.dart';
import 'services/preferences_service.dart';
import 'config/firebase_config.dart';

/**
 * 앱의 시작점
 * 
 * async로 선언되어 비동기 초기화 작업을 수행
 * - Firebase: 인증 및 Firestore 사용을 위한 초기화
 * - PreferencesService: 사용자 설정(폰트 크기 등) 저장/로드
 * - BibleService: 성경 본문 데이터 로딩
 */
void main() async {
  // Flutter 엔진과 위젯 바인딩을 초기화
  // async main()을 사용하기 위해 필수
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (FirebaseAuth, Firestore 사용 준비)
  await Firebase.initializeApp(
    options: FirebaseConfig.firebaseConfig,
  );

  // SharedPreferences 초기화 (사용자 설정 로드)
  await PreferencesService().init();

  // BibleService 초기화 (성경 본문 JSON 데이터 로드)
  await BibleService().initialize();

  // 앱 실행
  runApp(const ProclaimApp());
}

/**
 * ProclaimApp
 * 
 * 앱의 루트 위젯
 * MaterialApp을 반환하여 앱의 기본 구조와 테마를 정의
 */
class ProclaimApp extends StatelessWidget {
  const ProclaimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proclaim', // 앱 이름
      debugShowCheckedModeBanner: false, // 디버그 배너 숨김
      theme: ThemeData(
        primaryColor: const Color(0xFFCE6E26), // 앱 메인 컬러 (주황색)
      ),
      
      // StreamBuilder를 사용하여 로그인 상태를 실시간으로 감지
      // Firebase Auth의 상태 변화를 구독
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // 연결 대기 중일 때 로딩 표시
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 로그인되어 있으면 홈 화면 표시
          if (snapshot.hasData) {
            return const HomeScreen();
          } else {
            // 로그인되어 있지 않으면 로그인 화면 표시
            return const HomeScreen();
          }
        },
      ),
      
      // 네임드 라우트 정의 (pushNamed로 화면 전환 가능)
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const HomeScreen(),
      },
    );
  }
}

/**
 * SplashScreen
 * 
 * 앱 시작 시 표시되는 스플래시 화면
 * 
 * 기능:
 * - 로고 페이드인 + 확대 애니메이션
 * - 3초 후 로그인 상태 확인하여 자동 화면 전환
 * 
 * 주의: 현재 ProclaimApp에서 직접 사용되지 않음
 *      StreamBuilder로 로그인 상태를 확인하기 때문
 */
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/**
 * _SplashScreenState
 * 
 * 스플래시 화면의 애니메이션 로직을 처리하는 State 클래스
 */
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // 애니메이션 컨트롤러: 애니메이션의 진행 상태를 관리
  late AnimationController _controller;
  
  // 페이드인 애니메이션 (투명도 0 → 1)
  late Animation<double> _fadeAnimation;
  
  // 확대 애니메이션 (크기 0.5 → 1.0)
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 애니메이션 컨트롤러 생성 (1.5초 동안 진행)
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this, // SingleTickerProviderStateMixin 필요
    );

    // 페이드인 애니메이션 정의 (0.0 → 1.0, easeIn 곡선)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // 확대 애니메이션 정의 (0.5 → 1.0, easeOutBack 곡선)
    // easeOutBack: 목표 지점을 살짝 넘어갔다가 다시 돌아오는 효과
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // 애니메이션 시작
    _controller.forward();

    // 3초 후 다음 화면으로 전환
    Future.delayed(const Duration(seconds: 3), () {
      // mounted 체크: 위젯이 아직 화면에 있는지 확인
      if (mounted) {
        _navigateToNextScreen();
      }
    });
  }

  /**
   * 로그인 상태에 따라 적절한 화면으로 전환
   * - 로그인되어 있으면 → 홈 화면
   * - 로그인되어 있지 않으면 → 로그인 화면
   */
  void _navigateToNextScreen() {
    final authService = AuthService();

    // 현재 로그인 상태 확인
    if (authService.isLoggedIn) {
      // 로그인되어 있으면 홈 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // 로그인되어 있지 않으면 로그인 화면으로 이동
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    // 애니메이션 컨트롤러 해제 (메모리 누수 방지)
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCE6E26), // 주황색 배경
      body: Center(
        child: ScaleTransition(
          scale: _scaleAnimation, // 확대 애니메이션 적용
          child: FadeTransition(
            opacity: _fadeAnimation, // 페이드인 애니메이션 적용
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 이미지 표시
                Image.asset(
                  'assets/images/shofar_logo.png',
                  width: 250,
                  height: 250,
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
