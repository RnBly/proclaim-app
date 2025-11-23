import 'package:flutter/material.dart';
import 'translation_dialog.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';

class SettingsDialog extends StatefulWidget {
  final Translation currentTranslation;
  final double currentTitleFontSize;
  final double currentBodyFontSize;
  final Function(Translation) onTranslationChanged;
  final Function(double titleSize, double bodySize) onFontSizeChanged;

  const SettingsDialog({
    super.key,
    required this.currentTranslation,
    required this.currentTitleFontSize,
    required this.currentBodyFontSize,
    required this.onTranslationChanged,
    required this.onFontSizeChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _titleFontSize;
  late double _bodyFontSize;
  late Translation _selectedTranslation;
  final AuthService _authService = AuthService();

  // 기본값
  static const double DEFAULT_TITLE_SIZE = 20.0;
  static const double DEFAULT_BODY_SIZE = 16.0;

  // 범위 수정!
  static const double MIN_TITLE_SIZE = 18.0;
  static const double MAX_TITLE_SIZE = 40.0;
  static const double MIN_BODY_SIZE = 14.0;
  static const double MAX_BODY_SIZE = 32.0;

  @override
  void initState() {
    super.initState();
    _titleFontSize = widget.currentTitleFontSize;
    _bodyFontSize = widget.currentBodyFontSize;
    _selectedTranslation = widget.currentTranslation;
  }

  void _resetToDefault() {
    setState(() {
      _titleFontSize = DEFAULT_TITLE_SIZE;
      _bodyFontSize = DEFAULT_BODY_SIZE;
      _selectedTranslation = Translation.korean;
    });
  }

  String _getTranslationLabel(Translation translation) {
    switch (translation) {
      case Translation.korean:
        return '개역개정';
      case Translation.esv:
        return 'ESV';
      case Translation.compare:
        return '역본대조';
    }
  }

  void _showTranslationDialog() {
    showDialog(
      context: context,
      builder: (context) => TranslationDialog(
        currentTranslation: _selectedTranslation,
        onTranslationChanged: (translation) {
          setState(() {
            _selectedTranslation = translation;
          });
        },
      ),
    );
  }

  void _saveSettings() {
    widget.onTranslationChanged(_selectedTranslation);
    widget.onFontSizeChanged(_titleFontSize, _bodyFontSize);
    Navigator.pop(context);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // 설정 다이얼로그 닫기
        Navigator.of(context).pushReplacementNamed('/login'); // 로그인 화면으로
      }
    }
  }

  void _handleLogin() {
    Navigator.of(context).pop(); // 설정 다이얼로그 닫기

    // HomeScreen context에서 LoginScreen으로 교체
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더 (고정)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _resetToDefault,
                        tooltip: 'Default로 초기화',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 스크롤 가능한 컨텐츠
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 역본 비교 버튼
                    InkWell(
                      onTap: _showTranslationDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTranslationLabel(_selectedTranslation),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 글씨 크기 섹션
                    const Text(
                      '글씨 크기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 책 이름 글씨 크기
                    const Text(
                      '책 이름 글씨 크기',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '요한복음 3장(개역개정)',
                          style: TextStyle(
                            fontSize: _titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _titleFontSize,
                            min: MIN_TITLE_SIZE,
                            max: MAX_TITLE_SIZE,
                            divisions: ((MAX_TITLE_SIZE - MIN_TITLE_SIZE) / 2).round(),
                            onChanged: (value) {
                              setState(() {
                                _titleFontSize = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${_titleFontSize.round()}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 본문 글씨 크기
                    const Text(
                      '본문 글씨 크기',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '1. 하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니',
                        style: TextStyle(
                          fontSize: _bodyFontSize,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _bodyFontSize,
                            min: MIN_BODY_SIZE,
                            max: MAX_BODY_SIZE,
                            divisions: ((MAX_BODY_SIZE - MIN_BODY_SIZE) / 2).round(),
                            onChanged: (value) {
                              setState(() {
                                _bodyFontSize = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${_bodyFontSize.round()}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // 로그인/로그아웃 버튼
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _authService.isLoggedIn
                          ? OutlinedButton(
                        onPressed: _handleLogout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                          : ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF828282),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}