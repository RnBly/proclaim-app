/// home_screen.dart
/// 
/// 앱의 메인 화면
/// 
/// 주요 기능:
/// - 오늘 날짜의 성경 읽기 계획 표시 (구약, 시편, 신약)
/// - 각 읽기 계획 클릭 시 BiblePage로 이동
/// - 날짜 선택 버튼 (DatePickerDialog)
/// - 역본 선택 버튼 (TranslationDialog)
/// - 설정 버튼 (SettingsDialog)
/// - 묵상 작성 버튼 (MeditationWritingDialog)
/// - 하이라이트 기능
/// - 로그아웃 버튼
/// 
/// 데이터 흐름:
/// - BibleService에서 오늘 날짜의 읽기 계획 조회
/// - PreferencesService에서 폰트 크기 및 역본 설정 조회
/// - 설정 변경 시 화면 새로고침

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
import '../widgets/reading_mode_dialog.dart';
import 'bible_reader_screen.dart';
import 'monthly_reading_screen.dart';
import 'login_screen.dart';
import '../widgets/meditation_action_buttons.dart';
import '../widgets/highlight_options_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
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

  // 페이지별 스크롤 진행도 (각 페이지 독립적으로 관리)
  final Map<int, double> _scrollProgressByPage = {
    0: 0.0,  // 시편
    1: 0.0,  // 구약
    2: 0.0,  // 신약
  };

  // 하이라이트된 구절 정보 (book-chapter-verse -> color)
  Map<String, String> _highlightedVerses = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
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
              // 현재 페이지의 스크롤 진행도만 업데이트
              _scrollProgressByPage[_currentPage] = 
                  maxScroll > 0 ? currentScroll / maxScroll : 0.0;
            });
          }
          return false;
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
              // 페이지 전환 시 해당 페이지의 스크롤 진행도를 0으로 초기화
              _scrollProgressByPage[index] = 0.0;
            });
          },
          children: [
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
      floatingActionButton: _selectedVerses['old']!.isNotEmpty ||
              _selectedVerses['psalms']!.isNotEmpty ||
              _selectedVerses['new']!.isNotEmpty
          ? MeditationActionButtons(
              heroTagPrefix: 'home',
              opacity: _getButtonOpacity(),
              onCopyPressed: _copySelectedVerses,
              onHighlightPressed: _startHighlight,
              onMeditationPressed: _startMeditation,
              onHighlightLoginPrompt: () => _showLoginPrompt(isHighlight: true),
              onMeditationLoginPrompt: () => _showLoginPrompt(isHighlight: false),
            )
          : null,
    );
  }
  
  // 복사 버튼 투명도 계산 (현재 페이지의 스크롤 진행도 기준)
  double _getButtonOpacity() {
    final progress = _scrollProgressByPage[_currentPage] ?? 0.0;
    
    if (progress < 0.9) {
      return 1.0;
    } else {
      final normalizedProgress = (progress - 0.9) / 0.1;
      return 1.0 - (normalizedProgress * 0.5);
    }
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

  // 로그인 유도 다이얼로그
  void _showLoginPrompt({required bool isHighlight}) {
    final featureName = isHighlight ? '하이라이트' : '묵상';
    final iconColor = isHighlight ? Colors.green : const Color(0xFFCE6E26);
    final icon = isHighlight ? Icons.highlight : Icons.edit_note;

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
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 48,
                  color: iconColor,
                ),
              ),

              const SizedBox(height: 24),

              // 메시지
              Text(
                '로그인하면\n$featureName 기능을 사용할 수 있습니다',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                    backgroundColor: iconColor,
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

  // 하이라이트 시작
  Future<void> _startHighlight() async {
    final verses = await _getSelectedVerseReferences();

    if (verses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택된 구절이 없습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 색상 선택만
    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    // 하이라이트 저장
    await _saveHighlight(verses, color);
  }

  // 하이라이트 저장
  Future<void> _saveHighlight(
    List<VerseReference> verses,
    String color,
  ) async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final meditationService = MeditationService();
    final highlight = Meditation(
      id: meditationService.generateId(),
      userId: userId,
      verses: verses,
      content: '',  // 빈 문자열 = 하이라이트만
      highlightColor: color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await meditationService.saveMeditation(highlight);
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('하이라이트가 저장되었습니다'),
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

  // 묵상 시작
  Future<void> _startMeditation() async {
    // 선택된 구절들을 VerseReference로 변환
    final verses = await _getSelectedVerseReferences();

    if (verses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('선택된 구절이 없습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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

    for (var sheetType in ['psalms', 'old', 'new']) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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

  // 묵상/하이라이트 조회
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

    // 첫 번째 항목이 하이라이트인지 묵상인지 확인
    final first = meditations.first;
    
    if (first.content.isEmpty) {
      // 하이라이트 옵션 다이얼로그
      await showDialog(
        context: context,
        builder: (context) => HighlightOptionsDialog(
          highlight: first,
          onOptionSelected: (option) async {
            switch (option) {
              case HighlightOption.changeColor:
                await _changeHighlightColor(first);
                break;
              case HighlightOption.addMeditation:
                await _convertToMeditation(first);
                break;
              case HighlightOption.delete:
                await _deleteHighlight(first);
                break;
            }
          },
        ),
      );
      return;
    }

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
            context: dialogContext,
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
              Navigator.pop(dialogContext);

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
          try {
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

            if (confirm != true) return;

            final oldVerses = meditation.verses;
            final oldContent = meditation.content;
            final oldColor = meditation.highlightColor;

            await meditationService.deleteMeditation(userId, meditation.id);
            await _loadMeditations();

            if (mounted) {
              Navigator.pop(dialogContext);
            }

            await Future.delayed(const Duration(milliseconds: 100));

            if (!mounted) return;

            final content = await showDialog<String>(
              context: context,
              builder: (newContext) => MeditationWritingDialog(
                selectedVerses: oldVerses,
                initialContent: oldContent,
                initialColor: oldColor,
              ),
            );

            if (content == null || content.isEmpty) {
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

            final color = await showDialog<String>(
              context: context,
              builder: (colorContext) => const ColorSelectionDialog(),
            );

            if (color == null) {
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
            await _loadMeditations();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('묵상이 수정되었습니다'),
                  duration: Duration(seconds: 2),
                ),
              );

              await Future.delayed(const Duration(milliseconds: 300));

              if (mounted) {
                _viewMeditation(book, chapter, verse);
              }
            }
          } catch (e) {
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

  // 하이라이트 색상 변경
  Future<void> _changeHighlightColor(Meditation highlight) async {
    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    final authService = AuthService();
    final userId = authService.getUserId();
    if (userId == null) return;

    final meditationService = MeditationService();
    
    // 기존 삭제
    await meditationService.deleteMeditation(userId, highlight.id);
    
    // 새 색상으로 저장
    final updated = Meditation(
      id: meditationService.generateId(),
      userId: userId,
      verses: highlight.verses,
      content: '',
      highlightColor: color,
      createdAt: highlight.createdAt,
      updatedAt: DateTime.now(),
    );
    
    await meditationService.saveMeditation(updated);
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('색상이 변경되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 하이라이트를 묵상으로 전환
  Future<void> _convertToMeditation(Meditation highlight) async {
    // 묵상 작성 다이얼로그
    final content = await showDialog<String>(
      context: context,
      builder: (context) => MeditationWritingDialog(
        selectedVerses: highlight.verses,
      ),
    );

    if (content == null || content.isEmpty) return;

    final authService = AuthService();
    final userId = authService.getUserId();
    if (userId == null) return;

    final meditationService = MeditationService();
    
    // 기존 하이라이트 삭제
    await meditationService.deleteMeditation(userId, highlight.id);
    
    // 묵상으로 저장
    final meditation = Meditation(
      id: meditationService.generateId(),
      userId: userId,
      verses: highlight.verses,
      content: content,
      highlightColor: highlight.highlightColor,
      createdAt: highlight.createdAt,
      updatedAt: DateTime.now(),
    );
    
    await meditationService.saveMeditation(meditation);
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('묵상이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 하이라이트 삭제
  Future<void> _deleteHighlight(Meditation highlight) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('하이라이트 삭제'),
        content: const Text('이 하이라이트를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final authService = AuthService();
    final userId = authService.getUserId();
    if (userId == null) return;

    final meditationService = MeditationService();
    await meditationService.deleteMeditation(userId, highlight.id);
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('하이라이트가 삭제되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _copySelectedVerses() async {
    showDialog(
      context: context,
      builder: (dialogContext) => CopyDialog(
        onFormatSelected: (format) async {
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

    for (var sheetType in ['psalms', 'old', 'new']) {
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
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    for (var sheetType in ['psalms', 'old', 'new']) {
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
    
    return '$formattedText\n\n👇Today\'s Scripture Reading👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getCompareFormat() async {
    final List<SelectedVerseCompare> allSelected = [];

    for (var sheetType in ['psalms', 'old', 'new']) {
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
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<void> _showBibleSelectionDialog() async {
    final mode = await showDialog<String>(
      context: context,
      builder: (context) => const ReadingModeDialog(),
    );

    if (mode == null || !mounted) return;

    if (mode == 'daily') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const BibleReaderScreen(
              bookShort: '창',
              bookName: '창세기',
              bookEng: 'Genesis',
              initialChapter: 1,
              autoShowDialog: true,
            ),
          ),
        ).then((_) {
          _loadMeditations();
        });
      }
    } else if (mode == 'monthly') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MonthlyReadingScreen(),
          ),
        ).then((_) {
          _loadMeditations();
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}