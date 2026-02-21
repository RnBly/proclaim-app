/// monthly_reading_screen.dart
/// 
/// 한 달 통독 화면
/// 
/// 주요 기능:
/// - 매달 1일부터 30일까지의 통독 계획 표시
/// - 2페이지 구조: 1) 시편, 2) 구약+신약
/// - 날짜 선택 가능
/// - 역본 전환 (한글/ESV)
/// - 하이라이트 기능

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
import '../widgets/meditation_action_buttons.dart';
import '../widgets/highlight_options_dialog.dart';
import '../widgets/reading_calendar_dialog.dart';
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

  // 읽기 진행률
  double _scrollProgress = 0.0;
  double _psalmsProgress = 0.0;  // 시편 최대 진행률
  double _mainProgress = 0.0;    // 구·신약 최대 진행률
  final Set<int> _psalmsMilestones = {};
  final Set<int> _mainMilestones = {};
  // 완료 상태
  bool _psalmsCompleted = false;
  bool _isMainPageCompleted = false;
  bool _showMilestoneOverlay = false;
  int _milestonePercent = 0;
  AnimationController? _milestoneAnimController;
  Animation<double>? _milestoneOpacity;
  Animation<double>? _milestoneScale;

  final Map<String, Set<String>> _selectedVerses = {
    'monthly': {},
    'monthly_psalms': {},
  };

  // 하이라이트된 구절 정보
  Map<String, String> _highlightedVerses = {};

  @override
  void initState() {
    super.initState();
    _loadSavedPreferences();
    _loadMonthlyReadingPlan();
    _loadMeditations();
    _setupMilestoneAnimation();
    _loadCompletedState();
  }

  void _setupMilestoneAnimation() {
    _milestoneAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _milestoneOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_milestoneAnimController!);
    _milestoneScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.1), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(_milestoneAnimController!);
  }

  void _onScrollProgressChanged(double progress, String sheetType) {
    // sheetType으로 페이지 구분 (PageView 스와이프 중 _currentPage 오작동 방지)
    final isPsalms = sheetType == 'monthly_psalms';

    // 최대값만 유지 (뒤로 스크롤해도 줄어들지 않음)
    final maxProgress = isPsalms
        ? (progress > _psalmsProgress ? progress : _psalmsProgress)
        : (progress > _mainProgress ? progress : _mainProgress);

    setState(() {
      _scrollProgress = maxProgress;
      if (isPsalms) {
        _psalmsProgress = maxProgress;
      } else {
        _mainProgress = maxProgress;
      }
    });

    // 실시간 진행률 저장 (달력 반영용)
    final userId = AuthService().getUserId();
    if (userId != null) {
      PreferencesService().saveReadingProgress(userId, _selectedDate, sheetType, maxProgress);
    }

    // 마일스톤은 현재 보고 있는 페이지에서만 트리거
    if ((_currentPage == 0) != isPsalms) return;

    final percent = (maxProgress * 100).round();
    final milestones = isPsalms ? _psalmsMilestones : _mainMilestones;
    for (final milestone in [33, 66, 100]) {
      if (percent >= milestone && !milestones.contains(milestone)) {
        milestones.add(milestone);
        _triggerMilestone(milestone);
        break;
      }
    }
  }

  void _triggerMilestone(int percent) {
    HapticFeedback.mediumImpact();
    setState(() {
      _showMilestoneOverlay = true;
      _milestonePercent = percent;
    });
    _milestoneAnimController!.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _showMilestoneOverlay = false;
        });
      }
    });
  }

  // 완료 상태 로드
  void _loadCompletionState() {
    final userId = AuthService().getUserId();
    if (userId == null) return;
    setState(() {
      _isMainPageCompleted = PreferencesService().isReadingCompleted(userId, _selectedDate);
    });
  }

  // 날짜 완료 저장
  Future<void> _markDateCompleted() async {
    final userId = AuthService().getUserId();
    if (userId == null) return;
    await PreferencesService().saveReadingCompleted(userId, _selectedDate);
    if (mounted) {
      setState(() {
        _isMainPageCompleted = true;
      });
    }
  }

  // 완료 버튼 눌렀을 때
  Future<void> _onCompleteButtonPressed() async {
    final userId = AuthService().getUserId();
    if (userId == null) {
      _showLoginPromptSimple();
      return;
    }

    if (_currentPage == 0) {
      // 시편: 완료 표시 후 구·신약 페이지로 이동
      await PreferencesService().saveReadingProgress(userId, _selectedDate, 'monthly_psalms', 1.0);
      setState(() {
        _psalmsCompleted = true;
        _psalmsProgress = 1.0;
        _scrollProgress = 1.0;
      });
      if (mounted) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 시편 읽기 완료! 구·신약으로 이동합니다.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } else {
      // 구·신약: 완료 처리 후 달력 바로 표시
      await PreferencesService().saveReadingProgress(userId, _selectedDate, 'monthly', 1.0);
      await _markDateCompleted();
      setState(() {
        _mainProgress = 1.0;
        _scrollProgress = 1.0;
      });
      if (mounted) {
        _showProgressCalendar();
      }
    }
  }

  // 달력 다이얼로그 표시
  void _showProgressCalendar() {
    final userId = AuthService().getUserId();
    if (userId == null) {
      _showLoginPromptSimple();
      return;
    }
    showDialog(
      context: context,
      builder: (context) => ReadingCalendarDialog(
        userId: userId,
        currentDate: _selectedDate,
        onDateSelected: (date) {
          setState(() {
            _selectedDate = date;
            _selectedVerses['monthly']!.clear();
            _selectedVerses['monthly_psalms']!.clear();
            _scrollProgress = 0.0;
            _psalmsMilestones.clear();
            _mainMilestones.clear();
          });
          _loadCompletionState();
          _loadCompletedState();
        },
      ),
    );
  }

  // 간단한 로그인 유인 (달력/완료 버튼용)
  void _showLoginPromptSimple() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그인 필요'),
        content: const Text('읽기 진행 저장 및 달력 기능을 사용하려면\n로그인이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('로그인하기'),
          ),
        ],
      ),
    );
  }

  void _loadCompletedState() {
    final userId = AuthService().getUserId();
    if (userId == null) return;
    final prefs = PreferencesService();
    setState(() {
      _isMainPageCompleted = prefs.isReadingCompleted(userId, _selectedDate);
      _psalmsCompleted = _isMainPageCompleted ||
          prefs.getReadingProgress(userId, _selectedDate, 'monthly_psalms') >= 1.0;
      // 저장된 진행률 복원
      _psalmsProgress = prefs.getReadingProgress(userId, _selectedDate, 'monthly_psalms');
      _mainProgress = prefs.getReadingProgress(userId, _selectedDate, 'monthly');
      // 현재 페이지 진행률 표시
      _scrollProgress = _currentPage == 0 ? _psalmsProgress : _mainProgress;
    });
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
          _loadCompletionState();
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
    final isLoggedIn = AuthService().getUserId() != null;
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 달력 아이콘
                IconButton(
                  icon: Icon(
                    Icons.calendar_month,
                    color: isLoggedIn ? Colors.black87 : Colors.grey[400],
                  ),
                  onPressed: () {
                    if (isLoggedIn) {
                      _showProgressCalendar();
                    } else {
                      _showLoginPromptSimple();
                    }
                  },
                ),
                // 설정 아이콘
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.black87),
                  onPressed: _showSettingsDialog,
                ),
              ],
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
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

              // 프로그레스 바 (Nav 아래)
              _buildProgressBar(),

              // 페이지뷰
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      // 페이지 전환 시 해당 페이지의 저장된 진행률 표시
                      _scrollProgress = index == 0 ? _psalmsProgress : _mainProgress;
                      _psalmsMilestones.clear();
            _mainMilestones.clear();
                    });
                    _loadCompletedState();
                  },
                  children: [
                    _buildMonthlyPsalmsPage(),
                    _buildMonthlyReadingPage(),
                  ],
                ),
              ),
            ],
          ),

          // 마일스톤 오버레이
          if (_showMilestoneOverlay && _milestoneOpacity != null && _milestoneScale != null)
            AnimatedBuilder(
              animation: _milestoneAnimController!,
              builder: (context, child) {
                return Opacity(
                  opacity: _milestoneOpacity!.value,
                  child: Center(
                    child: Transform.scale(
                      scale: _milestoneScale!.value,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.blue[700]!.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '$_milestonePercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      floatingActionButton: _hasSelectedVerses()
          ? MeditationActionButtons(
              heroTagPrefix: 'monthly',
              onCopyPressed: _copySelectedVerses,
              onHighlightPressed: _startHighlight,
              onMeditationPressed: _showMeditationWritingDialog,
              onHighlightLoginPrompt: () => _showLoginPrompt(isHighlight: true),
              onMeditationLoginPrompt: () => _showLoginPrompt(isHighlight: false),
            )
          : null,
    );
  }

  // 하이라이트 시작
  Future<void> _startHighlight() async {
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

    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final meditationService = MeditationService();
    final highlight = Meditation(
      id: meditationService.generateId(),
      userId: userId,
      verses: verses,
      content: '',
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
        _selectedVerses['monthly']!.clear();
        _selectedVerses['monthly_psalms']!.clear();
      });
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

    final selectedVerses = await showDialog<List<VerseReference>>(
      context: context,
      builder: (context) => VerseSelectionDialog(
        availableVerses: verses,
      ),
    );

    if (selectedVerses == null || selectedVerses.isEmpty) return;

    if (!mounted) return;

    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => MeditationWritingDialog(
        selectedVerses: selectedVerses,
      ),
    );

    if (content == null || content.isEmpty) return;

    if (!mounted) return;

    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    await _saveMeditation(selectedVerses, content, color);
  }

  Future<List<VerseReference>> _getSelectedVerseReferences() async {
    final List<VerseReference> verses = [];
    final sheetType = _currentPage == 0 ? 'monthly_psalms' : 'monthly';
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
    await _loadMeditations();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('묵상이 저장되었습니다'),
          duration: Duration(seconds: 2),
        ),
      );
      
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

    final first = meditations.first;
    
    if (first.content.isEmpty) {
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
    await meditationService.deleteMeditation(userId, highlight.id);
    
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

  Future<void> _convertToMeditation(Meditation highlight) async {
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
    await meditationService.deleteMeditation(userId, highlight.id);
    
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

  void _showLoginPrompt({required bool isHighlight, bool isCalendar = false}) {
    final featureName = isCalendar ? '읽기 현황' : (isHighlight ? '하이라이트' : '묵상');
    final iconColor = isCalendar ? Colors.blue : (isHighlight ? Colors.green : const Color(0xFFCE6E26));
    final icon = isCalendar ? Icons.calendar_month : (isHighlight ? Icons.highlight : Icons.edit_note);

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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$featureName 기능',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$featureName 기능을 사용하려면\n로그인이 필요합니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
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
                    backgroundColor: iconColor,
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

  Widget _buildProgressBar() {
    final percent = (_scrollProgress * 100).round();
    return SizedBox(
      height: 13,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final barWidth = (totalWidth * _scrollProgress.clamp(0.0, 1.0));

          return Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.blue.shade50),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: barWidth,
                child: Container(color: Colors.blue[700]),
              ),
              Positioned(
                left: (barWidth - 25).clamp(0.0, totalWidth - 30),
                width: 30,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
    final isLoggedIn = AuthService().getUserId() != null;
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
      onScrollProgressChanged: _onScrollProgressChanged,
      isCompleted: _isMainPageCompleted,
      isLoggedIn: isLoggedIn,
      onCompletePressed: _onCompleteButtonPressed,
      onLoginPrompt: _showLoginPromptSimple,
      initialProgress: _mainProgress,
    );
  }

  Widget _buildMonthlyPsalmsPage() {
    final isLoggedIn = AuthService().getUserId() != null;
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
      onScrollProgressChanged: _onScrollProgressChanged,
      isCompleted: _psalmsCompleted,
      isLoggedIn: isLoggedIn,
      onCompletePressed: _onCompleteButtonPressed,
      onLoginPrompt: _showLoginPromptSimple,
      initialProgress: _psalmsProgress,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _milestoneAnimController?.dispose();
    super.dispose();
  }
}