/**
 * meditation_action_buttons.dart
 * 
 * 묵상 및 복사 기능을 제공하는 재사용 가능한 플로팅 액션 버튼 위젯
 * 
 * 사용되는 곳:
 * - HomeScreen (1일 묵상)
 * - BibleReaderScreen (성경 전체 읽기)
 * - MonthlyReadingScreen (한달 읽기)
 * 
 * 주요 기능:
 * - + 버튼 클릭 시 묵상/복사 버튼 확장
 * - 복사 버튼: 선택된 구절 복사
 * - 묵상 버튼: 로그인 시 묵상 작성, 비로그인 시 로그인 유도
 * - 애니메이션: ScaleTransition을 통한 부드러운 확장/축소
 * - Opacity 조절: 스크롤 위치에 따라 투명도 변경 가능
 */

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class MeditationActionButtons extends StatefulWidget {
  /// 복사 버튼 클릭 시 실행될 콜백
  final VoidCallback onCopyPressed;
  
  /// 묵상 버튼 클릭 시 실행될 콜백 (로그인 상태)
  final VoidCallback onMeditationPressed;
  
  /// 묵상 버튼 클릭 시 실행될 콜백 (비로그인 상태)
  final VoidCallback onLoginPrompt;
  
  /// 버튼의 투명도 (0.0 ~ 1.0)
  /// 스크롤 위치에 따라 투명도를 조절하고 싶을 때 사용
  final double opacity;
  
  /// FloatingActionButton의 고유 태그 접두사
  /// 여러 화면에서 사용할 때 heroTag 충돌을 방지하기 위해 사용
  final String heroTagPrefix;

  const MeditationActionButtons({
    super.key,
    required this.onCopyPressed,
    required this.onMeditationPressed,
    required this.onLoginPrompt,
    this.opacity = 1.0,
    this.heroTagPrefix = '',
  });

  @override
  State<MeditationActionButtons> createState() => _MeditationActionButtonsState();
}

class _MeditationActionButtonsState extends State<MeditationActionButtons>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    
    // 버튼 확장 애니메이션 설정
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  void _closeAndExecute(VoidCallback action) {
    setState(() {
      _isExpanded = false;
      _expandController.reverse();
    });
    action();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;

    return Opacity(
      opacity: widget.opacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 복사 버튼 (확장 시)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTransition(
                scale: _expandAnimation,
                child: FloatingActionButton(
                  heroTag: '${widget.heroTagPrefix}_copy',
                  onPressed: () => _closeAndExecute(widget.onCopyPressed),
                  backgroundColor: Colors.blue,
                  child: const Icon(
                    Icons.content_copy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

          // 묵상 버튼 (확장 시, 비로그인 시 반투명)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTransition(
                scale: _expandAnimation,
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 0.4,
                  child: FloatingActionButton(
                    heroTag: '${widget.heroTagPrefix}_meditation',
                    onPressed: () {
                      if (isLoggedIn) {
                        _closeAndExecute(widget.onMeditationPressed);
                      } else {
                        _closeAndExecute(widget.onLoginPrompt);
                      }
                    },
                    backgroundColor: const Color(0xFFCE6E26),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),

          // 메인 버튼 (+ 또는 X)
          FloatingActionButton(
            heroTag: '${widget.heroTagPrefix}_main',
            onPressed: _toggleExpanded,
            backgroundColor: _isExpanded ? Colors.grey : Colors.blue[700],
            elevation: 6.0,
            child: _isExpanded
                ? const Icon(Icons.close, color: Colors.white, size: 32)
                : Container(
                    alignment: Alignment.center,
                    child: const Text(
                      '+',
                      style: TextStyle(
                        fontSize: 40,
                        color: Colors.white,
                        fontWeight: FontWeight.w300,
                        height: 1.0,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}