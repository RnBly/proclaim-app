/**
 * bible_reader_screen.dart
 * 
 * 사용자가 선택한 성경 구절을 읽는 화면
 * 
 * 주요 기능:
 * - 한 페이지에 한 장 전체 표시
 * - 좌우 화살표로 장 이동
 * - 구절 선택 및 하이라이트
 * - 묵상 작성/보기
 * - 구절 복사
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bible_book.dart';
import '../models/bible_reading.dart';
import '../models/meditation.dart';
import '../services/bible_service.dart';
import '../services/auth_service.dart';
import '../services/meditation_service.dart';
import '../services/preferences_service.dart';
import '../widgets/meditation_writing_dialog.dart';
import '../widgets/meditation_view_dialog.dart';
import '../widgets/color_selection_dialog.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/translation_dialog.dart';
import '../widgets/bible_selection_dialog.dart';
import '../config/meditation_colors.dart';

class BibleReaderScreen extends StatefulWidget {
  final String bookShort;      // 예: "창"
  final String bookName;       // 예: "창세기"
  final String bookEng;        // 예: "Gen"
  final int initialChapter;    // 시작 장
  final int? initialVerse;     // 시작 절 (선택사항)

  const BibleReaderScreen({
    super.key,
    required this.bookShort,
    required this.bookName,
    required this.bookEng,
    required this.initialChapter,
    this.initialVerse,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> with TickerProviderStateMixin {
  late int _currentChapter;
  late BibleBook _currentBook;
  Translation _currentTranslation = Translation.korean;
  final Set<String> _selectedVerses = {};
  Map<String, String> _highlightedVerses = {};

  // 글씨 크기
  double _titleFontSize = 24.0;
  double _bodyFontSize = 18.0;

  // 묵상 버튼 애니메이션
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // 페이지 컨트롤러 (좌우 스와이프용)
  late PageController _pageController;

  // 스크롤 컨트롤러
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.initialChapter;
    
    // 현재 책 정보 찾기
    _currentBook = BibleBook.getAllBooks().firstWhere(
      (book) => book.koreanShort == widget.bookShort,
      orElse: () => BibleBook.getAllBooks().first,
    );

    // PageController 초기화 (현재 장 -1 = 인덱스)
    _pageController = PageController(initialPage: _currentChapter - 1);

    _loadSavedPreferences();
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

    // 초기 절로 스크롤 (build 후)
    if (widget.initialVerse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToVerse(widget.initialVerse!);
      });
    }
  }

  void _loadSavedPreferences() {
    final prefs = PreferencesService();
    setState(() {
      _titleFontSize = prefs.getTitleFontSize();
      _bodyFontSize = prefs.getBodyFontSize();

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

  Future<void> _loadMeditations() async {
    final authService = AuthService();
    final userId = authService.getUserId();

    if (userId == null) return;

    final meditationService = MeditationService();
    final meditations = await meditationService.getMeditations(userId);

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

  // 이전 장으로 이동
  void _previousChapter() {
    if (_currentChapter > 1) {
      setState(() {
        _currentChapter--;
        _selectedVerses.clear();
      });
    }
  }

  // 다음 장으로 이동
  void _nextChapter() {
    if (_currentChapter < _currentBook.totalChapters) {
      setState(() {
        _currentChapter++;
        _selectedVerses.clear();
      });
    }
  }

  // 구절 선택/해제
  void _toggleVerse(String key) {
    setState(() {
      if (_selectedVerses.contains(key)) {
        _selectedVerses.remove(key);
      } else {
        _selectedVerses.add(key);
      }
    });
  }

  bool _hasSelectedVerses() {
    return _selectedVerses.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isPsalms = _currentBook.koreanShort == '시';
    final unit = isPsalms ? '편' : '장';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentBook.koreanName} $_currentChapter$unit',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book, color: Colors.black87),
            onPressed: _showBibleSelectionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _currentBook.totalChapters,
        onPageChanged: (pageIndex) {
          setState(() {
            _currentChapter = pageIndex + 1;
            _selectedVerses.clear(); // 장이 바뀌면 선택 초기화
          });
        },
        itemBuilder: (context, index) {
          final chapter = index + 1;
          return _buildChapterContentForPage(chapter);
        },
      ),
      floatingActionButton: _hasSelectedVerses()
          ? _buildFloatingButtons()
          : null,
    );
  }

  // 장 내용 표시 (PageView용)
  Widget _buildChapterContentForPage(int chapter) {
    // 번역본에 따라 다른 뷰 표시
    switch (_currentTranslation) {
      case Translation.korean:
        return _buildKoreanView(chapter);
      case Translation.esv:
        return _buildEsvView(chapter);
      case Translation.compare:
        return _buildCompareView(chapter);
    }
  }

  // 한글 번역본 뷰
  Widget _buildKoreanView(int chapter) {
    final verses = BibleService().getVerses(
      _currentBook.koreanShort,
      chapter,
      chapter,
    );

    if (verses.isEmpty) {
      return const Center(
        child: Text('본문을 불러올 수 없습니다'),
      );
    }

    // GlobalKey 생성
    _verseKeys.clear();
    for (var verse in verses) {
      _verseKeys[verse.verseNumber] = GlobalKey();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: verses.map((verse) {
          final key = verse.key;
          final isSelected = _selectedVerses.contains(key);
          final highlightColor = _highlightedVerses[key];

          return Container(
            key: _verseKeys[verse.verseNumber],
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _toggleVerse(key),
              onLongPress: () {
                if (highlightColor != null) {
                  _viewMeditation(
                    _currentBook.koreanShort,
                    chapter,
                    verse.verseNumber,
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.1)
                      : (highlightColor != null
                          ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue
                        : (highlightColor != null
                            ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                            : Colors.transparent),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // 구절 텍스트
                    Padding(
                      padding: highlightColor != null
                          ? const EdgeInsets.only(right: 30)
                          : EdgeInsets.zero,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${verse.verseNumber}. ',
                              style: TextStyle(
                                fontSize: _bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            TextSpan(
                              text: verse.text,
                              style: TextStyle(
                                fontSize: _bodyFontSize,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 묵상 아이콘 (하이라이트된 구절에만 표시)
                    if (highlightColor != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _viewMeditation(
                            _currentBook.koreanShort,
                            chapter,
                            verse.verseNumber,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_note,
                              size: 16,
                              color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ESV 번역본 뷰
  Widget _buildEsvView(int chapter) {
    final verses = BibleService().getEsvVerses(
      _currentBook.englishShort,
      chapter,
      chapter,
    );

    if (verses.isEmpty) {
      return const Center(
        child: Text('ESV text could not be loaded'),
      );
    }

    // GlobalKey 생성
    _verseKeys.clear();
    for (var verse in verses) {
      _verseKeys[verse.verseNumber] = GlobalKey();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: verses.map((verse) {
          final key = '${_currentBook.koreanShort}-$chapter-${verse.verseNumber}';
          final isSelected = _selectedVerses.contains(key);
          final highlightColor = _highlightedVerses[key];

          return Container(
            key: _verseKeys[verse.verseNumber],
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _toggleVerse(key),
              onLongPress: () {
                if (highlightColor != null) {
                  _viewMeditation(
                    _currentBook.koreanShort,
                    chapter,
                    verse.verseNumber,
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.1)
                      : (highlightColor != null
                          ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue
                        : (highlightColor != null
                            ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                            : Colors.transparent),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: highlightColor != null
                          ? const EdgeInsets.only(right: 30)
                          : EdgeInsets.zero,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${verse.verseNumber}. ',
                              style: TextStyle(
                                fontSize: _bodyFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            TextSpan(
                              text: verse.text,
                              style: TextStyle(
                                fontSize: _bodyFontSize,
                                height: 1.6,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (highlightColor != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _viewMeditation(
                            _currentBook.koreanShort,
                            chapter,
                            verse.verseNumber,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_note,
                              size: 16,
                              color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // 역본대조 뷰
  // 역본대조 뷰
  Widget _buildCompareView(int chapter) {
    final koreanVerses = BibleService().getVerses(
      _currentBook.koreanShort,
      chapter,
      chapter,
    );

    final esvVerses = BibleService().getEsvVerses(
      _currentBook.englishShort,
      chapter,
      chapter,
    );

    if (koreanVerses.isEmpty || esvVerses.isEmpty) {
      return const Center(
        child: Text('본문을 불러올 수 없습니다'),
      );
    }

    // GlobalKey 생성
    _verseKeys.clear();
    for (var verse in koreanVerses) {
      _verseKeys[verse.verseNumber] = GlobalKey();
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(koreanVerses.length, (index) {
          final koreanVerse = koreanVerses[index];
          final esvVerse = index < esvVerses.length ? esvVerses[index] : null;
          final key = koreanVerse.key;
          final isSelected = _selectedVerses.contains(key);
          final highlightColor = _highlightedVerses[key];

          return Container(
            key: _verseKeys[koreanVerse.verseNumber],
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => _toggleVerse(key),
              onLongPress: () {
                if (highlightColor != null) {
                  _viewMeditation(
                    _currentBook.koreanShort,
                    chapter,
                    koreanVerse.verseNumber,
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withOpacity(0.1)
                      : (highlightColor != null
                          ? (MeditationColors.getColor(highlightColor) ?? Colors.grey).withOpacity(0.2)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Colors.blue
                        : (highlightColor != null
                            ? (MeditationColors.getColor(highlightColor) ?? Colors.grey)
                            : Colors.transparent),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 한글 구절
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${koreanVerse.verseNumber}. ',
                                style: TextStyle(
                                  fontSize: _bodyFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                              TextSpan(
                                text: koreanVerse.text,
                                style: TextStyle(
                                  fontSize: _bodyFontSize,
                                  height: 1.6,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // ESV 구절
                        if (esvVerse != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              esvVerse.text,
                              style: TextStyle(
                                fontSize: _bodyFontSize * 0.95,
                                height: 1.6,
                                color: Colors.grey.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (highlightColor != null)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _viewMeditation(
                            _currentBook.koreanShort,
                            chapter,
                            koreanVerse.verseNumber,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.edit_note,
                              size: 16,
                              color: MeditationColors.getColor(highlightColor) ?? Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 플로팅 버튼 (묵상/복사)
  Widget _buildFloatingButtons() {
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

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('묵상 기능을 사용하려면 로그인이 필요합니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // 성경 선택 다이얼로그 표시
  Future<void> _showBibleSelectionDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const BibleSelectionDialog(),
    );

    if (result != null && mounted) {
      final targetVerse = result['verse'] as int?;
      
      // 같은 책의 다른 장으로 이동하는 경우
      if (result['book'] == _currentBook.koreanShort) {
        setState(() {
          _currentChapter = result['chapter'];
          _selectedVerses.clear();
        });
        await _loadMeditations();
        
        // 선택한 절로 스크롤
        if (targetVerse != null) {
          _scrollToVerse(targetVerse);
        }
      } else {
        // 다른 책으로 이동하는 경우 - 새로운 BibleReaderScreen으로 교체
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BibleReaderScreen(
              bookShort: result['book'],
              bookName: result['bookName'],
              bookEng: result['bookEng'],
              initialChapter: result['chapter'],
            ),
          ),
        );
      }
    }
  }

  // 특정 절로 스크롤
  void _scrollToVerse(int verseNumber) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _verseKeys[verseNumber];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.0, // 맨 위에 위치
        );
      }
    });
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
          });
          // 설정에 저장
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
          // 설정에 저장
          final prefs = PreferencesService();
          prefs.saveTitleFontSize(titleSize);
          prefs.saveBodyFontSize(bodySize);
        },
      ),
    );
  }

  Future<void> _showMeditationWritingDialog() async {
    // 구절 본문 가져오기
    final verses = BibleService().getVerses(
      _currentBook.koreanShort,
      _currentChapter,
      _currentChapter,
    );

    final selectedVersesList = _selectedVerses.map((key) {
      final parts = key.split('-');
      final verseNumber = int.parse(parts[2]);
      
      // 해당 절 찾기
      final verseData = verses.firstWhere(
        (v) => v.verseNumber == verseNumber,
        orElse: () => Verse(book: parts[0], chapter: int.parse(parts[1]), verseNumber: verseNumber, text: ''),
      );
      
      return VerseReference(
        book: parts[0],
        chapter: int.parse(parts[1]),
        verse: verseNumber,
        text: verseData.text,
      );
    }).toList();

    // 1단계: 묵상 내용 작성
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => MeditationWritingDialog(
        selectedVerses: selectedVersesList,
      ),
    );

    if (content == null || content.isEmpty) return;

    // 2단계: 색상 선택
    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    // 3단계: 묵상 저장
    await _saveMeditation(selectedVersesList, content, color);
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
        _selectedVerses.clear();
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

  Future<void> _copySelectedVerses() async {
    showDialog(
      context: context,
      builder: (context) => CopyDialog(
        onFormatSelected: (format) async {
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
              _selectedVerses.clear();
            });
          }
        },
      ),
    );
  }

  Future<String> _getKoreanFormat() async {
    final List<SelectedVerse> allSelected = [];

    final verses = BibleService().getVerses(
      _currentBook.koreanShort,
      _currentChapter,
      _currentChapter,
    );

    for (var verse in verses) {
      if (_selectedVerses.contains(verse.key)) {
        allSelected.add(SelectedVerse(
          book: verse.book,
          fullName: _currentBook.koreanName,
          chapter: verse.chapter,
          verseNumber: verse.verseNumber,
          text: verse.text,
        ));
      }
    }

    return BibleService().formatSelectedVerses(allSelected);
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    final koreanVerses = BibleService().getVerses(
      _currentBook.koreanShort,
      _currentChapter,
      _currentChapter,
    );

    final esvVerses = BibleService().getEsvVerses(
      _currentBook.englishShort,
      _currentChapter,
      _currentChapter,
    );

    for (var koreanVerse in koreanVerses) {
      if (_selectedVerses.contains(koreanVerse.key)) {
        final esvVerse = esvVerses.firstWhere(
          (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );

        if (esvVerse.text.isNotEmpty) {
          allSelected.add(SelectedVerseEsv(
            bookEng: _currentBook.englishShort,
            fullNameEng: _currentBook.englishName,
            chapter: esvVerse.chapter,
            verseNumber: esvVerse.verseNumber,
            text: esvVerse.text,
          ));
        }
      }
    }

    return BibleService().formatSelectedVersesEsv(allSelected);
  }

  Future<String> _getCompareFormat() async {
    final List<SelectedVerseCompare> allSelected = [];

    final koreanVerses = BibleService().getVerses(
      _currentBook.koreanShort,
      _currentChapter,
      _currentChapter,
    );

    final esvVerses = BibleService().getEsvVerses(
      _currentBook.englishShort,
      _currentChapter,
      _currentChapter,
    );

    for (var koreanVerse in koreanVerses) {
      if (_selectedVerses.contains(koreanVerse.key)) {
        final esvVerse = esvVerses.firstWhere(
          (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );

        allSelected.add(SelectedVerseCompare(
          book: koreanVerse.book,
          fullName: _currentBook.koreanName,
          chapter: koreanVerse.chapter,
          verseNumber: koreanVerse.verseNumber,
          koreanText: koreanVerse.text,
          englishText: esvVerse.text,
        ));
      }
    }

    return BibleService().formatSelectedVersesCompare(allSelected);
  }

  @override
  void dispose() {
    _expandController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }
}