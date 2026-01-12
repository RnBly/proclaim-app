/**
 * home_screen.dart
 * 
 * 앱의 메인 화면
 * 
 * 주요 기능:
 * - 오늘 날짜의 성경 읽기 계획 표시 (구약, 시편, 신약)
 * - 각 읽기 계획 클릭 시 BiblePage로 이동
 * - 날짜 선택 버튼 (DatePickerDialog)
 * - 역본 선택 버튼 (TranslationDialog)
 * - 설정 버튼 (SettingsDialog)
 * - 묵상 작성 버튼 (MeditationWritingDialog)
 * - 로그아웃 버튼
 * 
 * 데이터 흐름:
 * - BibleService에서 오늘 날짜의 읽기 계획 조회
 * - PreferencesService에서 폰트 크기 및 역본 설정 조회
 * - 설정 변경 시 화면 새로고침
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../services/preferences_service.dart';
import '../services/auth_service.dart';
import '../services/meditation_service.dart';
import '../models/bible_reading.dart';
import '../models/meditation.dart';
import '../widgets/bible_page.dart';
import '../widgets/date_picker_dialog.dart' as custom;
import '../widgets/translation_dialog.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/verse_selection_dialog.dart';
import '../widgets/meditation_writing_dialog.dart';
import '../widgets/color_selection_dialog.dart';
import '../widgets/meditation_view_dialog.dart';
import '../widgets/bible_selection_dialog.dart';
import 'bible_reader_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime _selectedDate = DateTime.now();
  Translation _currentTranslation = Translation.korean;
  final Map<String, Set<String>> _selectedVerses = {
    'old': {},
    'psalms': {},
    'new': {},
  };

  // 글씨 크기 상태
  double _titleFontSize = 24.0;
  double _bodyFontSize = 18.0;

  double _scrollProgress = 0.0;

  // 묵상 기능 관련 상태
  bool _isExpanded = false; // 버튼 확장 상태
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // 하이라이트된 구절 정보 (book-chapter-verse -> color)
  Map<String, String> _highlightedVerses = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 화면이 표시될 때마다 묵상 로드
    _loadMeditations();
  }

  // 묵상 데이터 로드
  Future<void> _loadMeditations() async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) return;

    final meditationService = MeditationService();
    final meditations = await meditationService.getMeditations(userId);

    // 하이라이트 정보 추출
    final highlights = <String, String>{};
    for (var meditation in meditations) {
      for (var verse in meditation.verses) {
        final key = '${verse.book}-${verse.chapter}-${verse.verse}';
        highlights[key] = meditation.highlightColor;
      }
    }

    setState(() {
      _highlightedVerses = highlights;
    });
  }

  // 저장된 설정 불러오기
  void _loadSavedPreferences() {
    final prefs = PreferencesService();
    setState(() {
      _titleFontSize = prefs.getTitleFontSize();
      _bodyFontSize = prefs.getBodyFontSize();

      // 역본 불러오기
      final savedTranslation = prefs.getTranslation();
      if (savedTranslation == 'korean') {
        _currentTranslation = Translation.korean;
      } else if (savedTranslation == 'esv') {
        _currentTranslation = Translation.esv;
      } else if (savedTranslation == 'compare') {
        _currentTranslation = Translation.compare;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    final dateStr = '${_selectedDate.month}월 ${_selectedDate.day}일';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _showDatePicker,
              child: Text(
                '오늘의 말씀($dateStr)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_book, color: Colors.black87),
                  onPressed: _showBibleSelectionDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.black87),
                  onPressed: _showSettingsDialog,
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios,
                    color: _currentPage > 0 ? Colors.black87 : Colors.grey[300],
                  ),
                  onPressed: _currentPage > 0
                      ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
                IconButton(
                  icon: Icon(
                    Icons.arrow_forward_ios,
                    color: _currentPage < 2 ? Colors.black87 : Colors.grey[300],
                  ),
                  onPressed: _currentPage < 2
                      ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification) {
            final maxScroll = notification.metrics.maxScrollExtent;
            final currentScroll = notification.metrics.pixels;
            setState(() {
              _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
            });
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
              _scrollProgress = 0.0;
            });
          },
          children: [
            BiblePage(
              sheetType: 'old',
              selectedDate: _selectedDate,
              translation: _currentTranslation,
              selectedVerses: _selectedVerses['old']!,
              highlightedVerses: _highlightedVerses,
              onVerseToggle: (key) => _toggleVerse('old', key),
              onMeditationView: _viewMeditation,
              titleFontSize: _titleFontSize,
              bodyFontSize: _bodyFontSize,
            ),
            BiblePage(
              sheetType: 'psalms',
              selectedDate: _selectedDate,
              translation: _currentTranslation,
              selectedVerses: _selectedVerses['psalms']!,
              highlightedVerses: _highlightedVerses,
              onVerseToggle: (key) => _toggleVerse('psalms', key),
              onMeditationView: _viewMeditation,
              titleFontSize: _titleFontSize,
              bodyFontSize: _bodyFontSize,
            ),
            BiblePage(
              sheetType: 'new',
              selectedDate: _selectedDate,
              translation: _currentTranslation,
              selectedVerses: _selectedVerses['new']!,
              highlightedVerses: _highlightedVerses,
              onVerseToggle: (key) => _toggleVerse('new', key),
              onMeditationView: _viewMeditation,
              titleFontSize: _titleFontSize,
              bodyFontSize: _bodyFontSize,
            ),
          ],
        ),
      ),
      floatingActionButton: _hasSelectedVerses()
           ? _buildFloatingActionButtons()  // 복사 버튼만 표시
          : null,
    );
  }

  // 복사 버튼 투명도 계산
  double _getButtonOpacity() {
    if (_scrollProgress < 0.9) {
      return 1.0;
    } else {
      final normalizedProgress = (_scrollProgress - 0.9) / 0.1;
      return 1.0 - (normalizedProgress * 0.5);
    }
  }
  /*/ 복사 버튼만 표시 (묵상 기능 제거)
Widget _buildCopyButtonOnly() {
  return Opacity(
    opacity: _getButtonOpacity(),
    child: FloatingActionButton(
      heroTag: 'copy',
      onPressed: _copySelectedVerses,
      backgroundColor: Colors.blue,
      child: const Icon(
        Icons.content_copy,
        color: Colors.white,
        size: 24,
      ),
    ),
  );
}
*/
  _buildFloatingActionButtons() {
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;

    return Opacity(
      opacity: _getButtonOpacity(),
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
                  heroTag: 'copy',
                  onPressed: () {
                    setState(() {
                      _isExpanded = false;
                      _expandController.reverse();
                    });
                    _copySelectedVerses();
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(
                    Icons.content_copy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),

          // 묵상 버튼 (항상 표시, 비로그인 시 반투명)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTransition(
                scale: _expandAnimation,
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 0.4,  // 비로그인 시 투명
                  child: FloatingActionButton(
                    heroTag: 'meditation',
                    onPressed: () {
                      if (isLoggedIn) {
                        // 로그인됨 → 버튼 닫고 묵상 작성
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _startMeditation();
                      } else {
                        // 비로그인 → 버튼 닫고 로그인 유도
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _showLoginPrompt();
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
            heroTag: 'main',
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
                if (_isExpanded) {
                  _expandController.forward();
                } else {
                  _expandController.reverse();
                }
              });
            },
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
 
  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => custom.DatePickerDialog(
        initialDate: _selectedDate,
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
            _selectedVerses['old']!.clear();
            _selectedVerses['psalms']!.clear();
            _selectedVerses['new']!.clear();
          });
        },
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => SettingsDialog(
        currentTranslation: _currentTranslation,
        currentTitleFontSize: _titleFontSize,
        currentBodyFontSize: _bodyFontSize,
        onTranslationChanged: (translation) {
          setState(() {
            _currentTranslation = translation;
            _selectedVerses['old']!.clear();
            _selectedVerses['psalms']!.clear();
            _selectedVerses['new']!.clear();
          });
          final prefs = PreferencesService();
          if (translation == Translation.korean) {
            prefs.saveTranslation('korean');
          } else if (translation == Translation.esv) {
            prefs.saveTranslation('esv');
          } else if (translation == Translation.compare) {
            prefs.saveTranslation('compare');
          }
        },
        onFontSizeChanged: (titleSize, bodySize) {
          setState(() {
            _titleFontSize = titleSize;
            _bodyFontSize = bodySize;
          });
          final prefs = PreferencesService();
          prefs.saveTitleFontSize(titleSize);
          prefs.saveBodyFontSize(bodySize);
        },
      ),
    );
  }

  void _toggleVerse(String sheetType, String key) {
    setState(() {
      if (_selectedVerses[sheetType]!.contains(key)) {
        _selectedVerses[sheetType]!.remove(key);
      } else {
        _selectedVerses[sheetType]!.add(key);
      }
    });
  }

  bool _hasSelectedVerses() {
    return _selectedVerses.values.any((set) => set.isNotEmpty);
  }

  // 로그인 유도 다이얼로그
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // X 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 아이콘
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFCE6E26).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note,
                  size: 48,
                  color: Color(0xFFCE6E26),
                ),
              ),

              const SizedBox(height: 24),

              // 메시지
              const Text(
                '로그인하면\n묵상 기록이 가능합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                '지금 로그인하시겠어요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 32),

              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // 다이얼로그 닫기

                    // 로그인 화면으로 이동
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCE6E26),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 묵상 시작
  Future<void> _startMeditation() async {
    // 선택된 구절들을 VerseReference로 변환
    final verses = await _getSelectedVerseReferences();

    if (verses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선택된 구절이 없습니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // 1단계: 묵상 절 선택 다이얼로그
    final selectedVerses = await showDialog<List<VerseReference>>(
      context: context,
      builder: (context) => VerseSelectionDialog(
        availableVerses: verses,
      ),
    );

    if (selectedVerses == null || selectedVerses.isEmpty) return;

    // 2단계: 묵상 기록 작성 다이얼로그
    final content = await showDialog<String>(
      context: context,
      builder: (context) => MeditationWritingDialog(
        selectedVerses: selectedVerses,
      ),
    );

    if (content == null || content.isEmpty) return;

    // 3단계: 색상 선택 다이얼로그
    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    // 묵상 저장
    await _saveMeditation(selectedVerses, content, color);
  }

  // 선택된 구절들을 VerseReference로 변환
  Future<List<VerseReference>> _getSelectedVerseReferences() async {
    final List<VerseReference> verses = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final readings = BibleService().getAllReadingsForDate(_selectedDate, sheetType);

      for (var reading in readings) {

        final koreanVerses = BibleService().getVerses(
          reading.book,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        for (var verse in koreanVerses) {
          if (_selectedVerses[sheetType]!.contains(verse.key)) {
            verses.add(VerseReference(
              book: verse.book,
              chapter: verse.chapter,
              verse: verse.verseNumber,
              text: verse.text,
            ));
          }
        }
      }
    }

    return verses;
  }

  // 묵상 저장
  Future<void> _saveMeditation(
      List<VerseReference> verses,
      String content,
      String color,
      ) async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final meditationService = MeditationService();
    final meditation = Meditation(
      id: meditationService.generateId(),
      userId: userId,
      verses: verses,
      content: content,
      highlightColor: color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await meditationService.saveMeditation(meditation);

    // 하이라이트 새로고침
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('묵상이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedVerses['old']!.clear();
        _selectedVerses['psalms']!.clear();
        _selectedVerses['new']!.clear();
      });
    }
  }

  // 묵상 조회
  // 묵상 조회 - BuildContext 문제 완전 해결 버전
  Future<void> _viewMeditation(String book, int chapter, int verse) async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) return;

    final meditationService = MeditationService();
    final meditations = await meditationService.getMeditationsByVerse(
      userId,
      book,
      chapter,
      verse,
    );

    if (meditations.isEmpty) return;

    if (!mounted) return;

    // 묵상 조회 다이얼로그 표시
    await showDialog(
      context: context,
      builder: (dialogContext) => MeditationViewDialog(
        meditations: meditations,
        initialIndex: 0,
        onDelete: (meditationId) async {
          // 삭제 확인 다이얼로그
          if (!mounted) return;

          final confirm = await showDialog<bool>(
            context: dialogContext, // ⭐ dialogContext 사용
            builder: (deleteContext) => AlertDialog(
              title: const Text('묵상 삭제'),
              content: const Text('이 묵상을 삭제하시겠습니까?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(deleteContext, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(deleteContext, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('삭제'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await meditationService.deleteMeditation(userId, meditationId);
            await _loadMeditations();

            if (mounted) {
              Navigator.pop(dialogContext); // 묵상 조회 다이얼로그 닫기

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('묵상이 삭제되었습니다'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
        onEdit: (meditation) async {
          print('🔧 수정 시작: ${meditation.id}');

          try {
            // 1단계: 먼저 수정 확인 다이얼로그
            final confirm = await showDialog<bool>(
              context: dialogContext,
              builder: (confirmContext) => AlertDialog(
                title: const Text('묵상 수정'),
                content: const Text('정말 수정하시겠습니까?\n기존 묵상이 삭제되고 새로 작성하실 수 있습니다.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmContext, false),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(confirmContext, true),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFCE6E26),
                    ),
                    child: const Text('확인'),
                  ),
                ],
              ),
            );

            if (confirm != true) {
              print('❌ 수정 취소됨');
              return;
            }

            // 2단계: 기존 묵상 데이터 복사
            final oldVerses = meditation.verses;
            final oldContent = meditation.content;
            final oldColor = meditation.highlightColor;
            print('📋 기존 데이터 복사 완료');

            // 3단계: 기존 묵상 삭제
            await meditationService.deleteMeditation(userId, meditation.id);
            await _loadMeditations();
            print('🗑️ 기존 묵상 삭제 완료');

            // 4단계: 묵상 조회 다이얼로그 닫기
            Navigator.pop(dialogContext);

            // 잠시 대기 (UI 업데이트 시간 확보)
            await Future.delayed(const Duration(milliseconds: 100));

            if (!mounted) return;

            // 5단계: 새 묵상 작성 다이얼로그 (기존 내용으로 미리 채움)
            final content = await showDialog<String>(
              context: context,
              builder: (newContext) => MeditationWritingDialog(
                selectedVerses: oldVerses,
                initialContent: oldContent,
                initialColor: oldColor,
              ),
            );

            if (content == null || content.isEmpty) {
              print('❌ 새 묵상 작성 취소됨 - 원본 묵상은 이미 삭제됨');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('묵상 작성이 취소되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            print('📝 새 내용 작성 완료: $content');

            // 6단계: 색상 선택
            final color = await showDialog<String>(
              context: context,
              builder: (colorContext) => const ColorSelectionDialog(),
            );

            if (color == null) {
              print('❌ 색상 선택 취소됨 - 묵상 저장하지 않음');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('색상 선택이 취소되었습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              return;
            }
            print('🎨 선택된 색상: $color');

            // 7단계: 새 묵상으로 저장
            final newMeditation = Meditation(
              id: meditationService.generateId(),
              userId: userId,
              verses: oldVerses,
              content: content,
              highlightColor: color,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await meditationService.saveMeditation(newMeditation);
            print('✅ 새 묵상 저장 완료: ${newMeditation.id}');

            // 8단계: 하이라이트 새로고침
            await _loadMeditations();
            print('✅ 하이라이트 업데이트 완료');

            if (mounted) {
              // 성공 메시지
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('묵상이 수정되었습니다'),
                  duration: Duration(seconds: 2),
                ),
              );

              // 잠시 대기 후 수정된 묵상 다시 열기
              await Future.delayed(const Duration(milliseconds: 300));

              if (mounted) {
                _viewMeditation(book, chapter, verse);
              }
            }
          } catch (e) {
            print('❌ 전체 오류: $e');

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('오류 발생: $e'),
                  duration: const Duration(seconds: 3),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _copySelectedVerses() async {
    showDialog(
      context: context,
      builder: (dialogContext) => CopyDialog(
        onFormatSelected: (format) async {
          // 다이얼로그 먼저 닫기
          Navigator.pop(dialogContext);

          String formatted = '';

          if (format == CopyFormat.korean) {
            formatted = await _getKoreanFormat();
          } else if (format == CopyFormat.esv) {
            formatted = await _getEsvFormat();
          } else {
            formatted = await _getCompareFormat();
          }

          await Clipboard.setData(ClipboardData(text: formatted));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('복사 되었습니다'),
                duration: Duration(seconds: 2),
              ),
            );

            setState(() {
              _selectedVerses['old']!.clear();
              _selectedVerses['psalms']!.clear();
              _selectedVerses['new']!.clear();
            });
          }
        },
      ),
    );
  }

  Future<String> _getKoreanFormat() async {
    final List<SelectedVerse> allSelected = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final readings = BibleService().getAllReadingsForDate(_selectedDate, sheetType);

      for (var reading in readings) {

        final verses = BibleService().getVerses(
          reading.book,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        for (var verse in verses) {
          if (_selectedVerses[sheetType]!.contains(verse.key)) {
            allSelected.add(SelectedVerse(
              book: verse.book,
              fullName: reading.fullName,
              chapter: verse.chapter,
              verseNumber: verse.verseNumber,
              text: verse.text,
            ));
          }
        }
      }
    }

    final formattedText = BibleService().formatSelectedVerses(allSelected);
    
    // 앱 링크 추가
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final readings = BibleService().getAllReadingsForDate(_selectedDate, sheetType);

      for (var reading in readings) {

        final koreanVerses = BibleService().getVerses(
          reading.book,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        final esvVerses = BibleService().getEsvVerses(
          reading.bookEng,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        for (var koreanVerse in koreanVerses) {
          if (_selectedVerses[sheetType]!.contains(koreanVerse.key)) {
            final esvVerse = esvVerses.firstWhere(
                  (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
              orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
            );

            if (esvVerse.text.isNotEmpty) {
              allSelected.add(SelectedVerseEsv(
                bookEng: reading.bookEng,
                fullNameEng: reading.fullNameEng,
                chapter: esvVerse.chapter,
                verseNumber: esvVerse.verseNumber,
                text: esvVerse.text,
              ));
            }
          }
        }
      }
    }

    final formattedText = BibleService().formatSelectedVersesEsv(allSelected);
    
    // 앱 링크 추가
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getCompareFormat() async {
    final List<SelectedVerseCompare> allSelected = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final readings = BibleService().getAllReadingsForDate(_selectedDate, sheetType);

      for (var reading in readings) {

        final koreanVerses = BibleService().getVerses(
          reading.book,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        final esvVerses = BibleService().getEsvVerses(
          reading.bookEng,
          reading.startChapter,
          reading.endChapter,
          verseRange: reading.verseRange,
        );

        for (var koreanVerse in koreanVerses) {
          if (_selectedVerses[sheetType]!.contains(koreanVerse.key)) {
            final esvVerse = esvVerses.firstWhere(
                  (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
              orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
            );

            allSelected.add(SelectedVerseCompare(
              book: koreanVerse.book,
              fullName: reading.fullName,
              chapter: koreanVerse.chapter,
              verseNumber: koreanVerse.verseNumber,
              koreanText: koreanVerse.text,
              englishText: esvVerse.text,
            ));
          }
        }
      }
    }

    final formattedText = BibleService().formatSelectedVersesCompare(allSelected);
    
    // 앱 링크 추가
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  // 성경 선택 다이얼로그 표시
  Future<void> _showBibleSelectionDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const BibleSelectionDialog(),
    );

    if (result != null && mounted) {
      // 선택된 책/장/절로 성경 읽기 화면 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BibleReaderScreen(
            bookShort: result['book'],
            bookName: result['bookName'],
            bookEng: result['bookEng'],
            initialChapter: result['chapter'],
          ),
        ),
      ).then((_) {
        // 성경 읽기 화면에서 돌아왔을 때 묵상 다시 로드
        _loadMeditations();
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _expandController.dispose();
    super.dispose();
  }
}