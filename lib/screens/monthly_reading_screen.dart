/// monthly_reading_screen.dart
/// 
/// 한 달 통독 화면
/// 
/// 주요 기능:
/// - 매달 1일부터 30일까지의 통독 계획 표시
/// - 2페이지 구조: 1) 시편, 2) 구약+신약
/// - 날짜 선택 가능
/// - 역본 전환 (한글/ESV)

library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../services/auth_service.dart';
import '../services/meditation_service.dart';
import '../services/preferences_service.dart';
import '../models/bible_reading.dart';
import '../models/meditation.dart';
import '../widgets/bible_page.dart';
import '../widgets/translation_dialog.dart';
import '../widgets/meditation_writing_dialog.dart';
import '../widgets/meditation_view_dialog.dart';
import '../widgets/color_selection_dialog.dart';
import '../widgets/verse_selection_dialog.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/date_picker_dialog.dart' as custom;
import 'login_screen.dart';

class MonthlyReadingScreen extends StatefulWidget {
  const MonthlyReadingScreen({super.key});

  @override
  State<MonthlyReadingScreen> createState() => _MonthlyReadingScreenState();
}

class _MonthlyReadingScreenState extends State<MonthlyReadingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime _selectedDate = DateTime.now();
  Translation _currentTranslation = Translation.korean;

  // 글씨 크기 상태
  double _titleFontSize = 24.0;
  double _bodyFontSize = 18.0;

  final Map<String, Set<String>> _selectedVerses = {
    'monthly': {},
    'monthly_psalms': {},
  };

  // 하이라이트된 구절 정보
  final Map<String, String> _highlightedVerses = {};

  // 묵상 버튼 애니메이션
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
    _loadMonthlyReadingPlan();
    _loadMeditations();

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

  Future<void> _loadSavedPreferences() async {
    _titleFontSize = PreferencesService().getTitleFontSize();
    _bodyFontSize = PreferencesService().getBodyFontSize();
    
    final translationString = PreferencesService().getTranslation();
    if (translationString == 'korean') {
      _currentTranslation = Translation.korean;
    } else if (translationString == 'esv') {
      _currentTranslation = Translation.esv;
    } else if (translationString == 'compare') {
      _currentTranslation = Translation.compare;
    }
    
    setState(() {});
  }

  Future<void> _loadMonthlyReadingPlan() async {
    await BibleService().loadMonthlyReadingPlan();
    setState(() {});
  }

  Future<void> _loadMeditations() async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) return;

    final meditationService = MeditationService();
    final meditations = await meditationService.getMeditations(userId);

    final Map<String, String> highlights = {};
    for (var meditation in meditations) {
      for (var verse in meditation.verses) {
        final key = '${verse.book}-${verse.chapter}-${verse.verse}';
        highlights[key] = meditation.highlightColor;
      }
    }

    if (mounted) {
      setState(() {
        _highlightedVerses.clear();
        _highlightedVerses.addAll(highlights);
      });
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
            _selectedVerses['monthly']!.clear();
            _selectedVerses['monthly_psalms']!.clear();
          });
        },
      ),
    );
  }

  void _showTranslationDialog() {
    showDialog(
      context: context,
      builder: (context) => TranslationDialog(
        currentTranslation: _currentTranslation,
        onTranslationChanged: (translation) {
          setState(() {
            _currentTranslation = translation;
            _selectedVerses['monthly']!.clear();
            _selectedVerses['monthly_psalms']!.clear();
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
            _selectedVerses['monthly']!.clear();
            _selectedVerses['monthly_psalms']!.clear();
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

  void _toggleVerse(String key) {
    setState(() {
      final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
      if (_selectedVerses[sheetType]!.contains(key)) {
        _selectedVerses[sheetType]!.remove(key);
      } else {
        _selectedVerses[sheetType]!.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 표시 (30일 초과시 30일로 제한)
    int displayDay = _selectedDate.day > 30 ? 30 : _selectedDate.day;
    String dateStr = '${_selectedDate.month}월 $displayDay일';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _showDatePicker,
              child: Text(
                '한 달 통독 ($dateStr)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.black87),
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 페이지 인디케이터
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPageIndicator(0, '시편'),
                const SizedBox(width: 8),
                _buildPageIndicator(1, '구·신약'),
              ],
            ),
          ),

          // 페이지뷰
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildMonthlyPsalmsPage(),
                _buildMonthlyReadingPage(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _hasSelectedVerses()
          ? _buildFloatingActionButtons()
          : null,
    );
  }

  Widget _buildFloatingActionButtons() {
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;

    return Column(
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

        // 묵상 버튼 (확장 시, 비로그인 시 반투명)
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ScaleTransition(
              scale: _expandAnimation,
              child: Opacity(
                opacity: isLoggedIn ? 1.0 : 0.4,
                child: FloatingActionButton(
                  heroTag: 'meditation',
                  onPressed: () {
                    if (isLoggedIn) {
                      setState(() {
                        _isExpanded = false;
                        _expandController.reverse();
                      });
                      _showMeditationWritingDialog();
                    } else {
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
    );
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
              _selectedVerses['monthly']!.clear();
              _selectedVerses['monthly_psalms']!.clear();
            });
          }
        },
      ),
    );
  }

  Future<String> _getKoreanFormat() async {
    final List<SelectedVerse> allSelected = [];

    final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
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

    final formattedText = BibleService().formatSelectedVerses(allSelected);
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
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
            orElse: () => Verse(
              book: reading.bookEng,
              chapter: koreanVerse.chapter,
              verseNumber: koreanVerse.verseNumber,
              text: '',
            ),
          );

          allSelected.add(SelectedVerseEsv(
            bookEng: reading.bookEng,
            fullNameEng: reading.fullNameEng,
            chapter: koreanVerse.chapter,
            verseNumber: koreanVerse.verseNumber,
            text: esvVerse.text,
          ));
        }
      }
    }

    final formattedText = BibleService().formatSelectedVersesEsv(allSelected);
    
    return '$formattedText\n\n👇Today\'s Scripture Reading👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getCompareFormat() async {
    final List<SelectedVerseCompare> allSelected = [];

    final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
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
            orElse: () => Verse(
              book: reading.bookEng,
              chapter: koreanVerse.chapter,
              verseNumber: koreanVerse.verseNumber,
              text: '',
            ),
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

    final formattedText = BibleService().formatSelectedVersesCompare(allSelected);
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  bool _hasSelectedVerses() {
    return _selectedVerses.values.any((set) => set.isNotEmpty);
  }

  Future<void> _showMeditationWritingDialog() async {
    final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
    
    // 선택된 구절들을 VerseReference로 변환
    final verses = await _getSelectedVerseReferences(sheetType);

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

    if (!mounted) return;

    // 2단계: 묵상 기록 작성 다이얼로그
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => MeditationWritingDialog(
        selectedVerses: selectedVerses,
      ),
    );

    if (content == null || content.isEmpty) return;

    if (!mounted) return;

    // 3단계: 색상 선택
    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    // 4단계: 묵상 저장
    await _saveMeditation(selectedVerses, content, color);
  }

  // 선택된 구절들을 VerseReference로 변환
  Future<List<VerseReference>> _getSelectedVerseReferences(String sheetType) async {
    final List<VerseReference> verses = [];
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

    return verses;
  }

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
      
      // 선택 초기화
      setState(() {
        _selectedVerses[_currentPage == 0 ? 'monthly_psalms' : 'monthly']!.clear();
      });
    }
  }

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

    await showDialog(
      context: context,
      builder: (dialogContext) => MeditationViewDialog(
        meditations: meditations,
        initialIndex: 0,
        onDelete: (meditationId) async {
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

            Navigator.pop(dialogContext);
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

            if (!mounted) return;

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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_note,
                  size: 32,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 20),
              // 제목
              const Text(
                '묵상 기능',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // 설명
              Text(
                '묵상 기능을 사용하려면\n로그인이 필요합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              // 로그인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '로그인하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 닫기 버튼
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int pageIndex, String label) {
    final isActive = _currentPage == pageIndex;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          pageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue[700] : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyReadingPage() {
    return BiblePage(
      key: ValueKey('monthly_${_selectedDate.month}_${_selectedDate.day}'),
      sheetType: 'monthly',
      selectedDate: _selectedDate,
      translation: _currentTranslation,
      selectedVerses: _selectedVerses['monthly']!,
      highlightedVerses: _highlightedVerses,
      onVerseToggle: _toggleVerse,
      onMeditationView: _viewMeditation,
      titleFontSize: _titleFontSize,
      bodyFontSize: _bodyFontSize,
    );
  }

  Widget _buildMonthlyPsalmsPage() {
    return BiblePage(
      key: ValueKey('monthly_psalms_${_selectedDate.month}_${_selectedDate.day}'),
      sheetType: 'monthly_psalms',
      selectedDate: _selectedDate,
      translation: _currentTranslation,
      selectedVerses: _selectedVerses['monthly_psalms']!,
      highlightedVerses: _highlightedVerses,
      onVerseToggle: _toggleVerse,
      onMeditationView: _viewMeditation,
      titleFontSize: _titleFontSize,
      bodyFontSize: _bodyFontSize,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}