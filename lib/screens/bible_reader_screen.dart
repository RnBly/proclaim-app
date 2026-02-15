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
 * - 하이라이트 기능 (색상만 표시)
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
import '../widgets/verse_selection_dialog.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/translation_dialog.dart';
import '../widgets/bible_selection_dialog.dart';
import '../widgets/highlight_options_dialog.dart';
import '../config/meditation_colors.dart';

class BibleReaderScreen extends StatefulWidget {
  final String bookShort;      // 예: "창"
  final String bookName;       // 예: "창세기"
  final String bookEng;        // 예: "Gen"
  final int initialChapter;    // 시작 장
  final int? initialVerse;     // 시작 절 (선택사항)
  final bool autoShowDialog;   // 1초 후 자동으로 성경 선택 다이얼로그 표시 여부

  const BibleReaderScreen({
    super.key,
    required this.bookShort,
    required this.bookName,
    required this.bookEng,
    required this.initialChapter,
    this.initialVerse,
    this.autoShowDialog = false,
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
  double _scrollProgress = 0.0; // 스크롤 진행률 (0.0 ~ 1.0);

  // 성경 선택 다이얼로그 표시 가능 여부 (1초 후 true)
  bool _canShowDialog = false;

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

    // 스크롤 리스너 추가
    _scrollController.addListener(_updateScrollProgress);

    // autoShowDialog가 true면 1초 후 자동으로 성경 선택 다이얼로그 표시
    if (widget.autoShowDialog) {
      // autoShowDialog일 때는 initialVerse 스크롤 건너뛰기 (다이얼로그에서 선택 후 스크롤)
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _canShowDialog = true;
          });
          _showBibleSelectionDialog();
        }
      });
    } else {
      // autoShowDialog가 false면 즉시 선택 가능
      _canShowDialog = true;
      
      // 초기 절로 스크롤 (build 후)
      if (widget.initialVerse != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // 충분한 지연을 두고 스크롤 (키가 완전히 생성될 시간 확보)
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _scrollToVerse(widget.initialVerse!);
            }
          });
        });
      }
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

  void _updateScrollProgress() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress = maxScroll > 0 ? currentScroll / maxScroll : 0.0;
      });
    }
  }

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

  void _scrollToVerse(int verseNumber) {
    final key = _verseKeys[verseNumber];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.2, // 화면 상단 20% 위치에 표시
      );
    }
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
            icon: Icon(
              Icons.menu_book, 
              color: _canShowDialog ? Colors.black87 : Colors.grey[300],
            ),
            onPressed: _canShowDialog ? _showBibleSelectionDialog : null,
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
            _selectedVerses.clear();
            _scrollProgress = 0.0;
          });
          _loadMeditations();
        },
        itemBuilder: (context, pageIndex) {
          final chapter = pageIndex + 1;
          return _buildChapterPage(chapter);
        },
      ),
      floatingActionButton: _hasSelectedVerses()
          ? _buildFloatingActionButtons()
          : null,
    );
  }

  Widget _buildChapterPage(int chapter) {
    final verses = BibleService().getVerses(
      _currentBook.koreanShort,
      chapter,
      chapter,
    );

    if (verses.isEmpty) {
      return const Center(
        child: Text('구절을 불러올 수 없습니다'),
      );
    }

    // ESV 구절 가져오기
    final esvVerses = BibleService().getEsvVerses(
      _currentBook.englishShort,
      chapter,
      chapter,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          _updateScrollProgress();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: verses.length,
        itemBuilder: (context, index) {
          final verse = verses[index];
          final verseKey = '${verse.book}-${verse.chapter}-${verse.verseNumber}';
          
          // 해당 절에 대한 GlobalKey 생성
          _verseKeys[verse.verseNumber] = GlobalKey();

          final isSelected = _selectedVerses.contains(verseKey);
          final isHighlighted = _highlightedVerses.containsKey(verseKey);
          final highlightColor = isHighlighted 
              ? MeditationColors.getColor(_highlightedVerses[verseKey]!)
              : null;

          // ESV 번역 찾기
          final esvVerse = esvVerses.firstWhere(
            (v) => v.verseNumber == verse.verseNumber,
            orElse: () => Verse(
              book: '',
              chapter: 0,
              verseNumber: 0,
              text: '',
            ),
          );

          return GestureDetector(
            key: _verseKeys[verse.verseNumber],
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedVerses.remove(verseKey);
                } else {
                  _selectedVerses.add(verseKey);
                }
              });
            },
            onLongPress: isHighlighted
                ? () => _viewMeditation(verse.book, verse.chapter, verse.verseNumber)
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.1)
                    : (highlightColor?.withOpacity(0.2) ?? Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? Colors.blue
                      : (highlightColor ?? Colors.transparent),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 한글 구절
                  if (_currentTranslation == Translation.korean ||
                      _currentTranslation == Translation.compare)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${verse.verseNumber}',
                          style: TextStyle(
                            fontSize: _bodyFontSize - 2,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            verse.text,
                            style: TextStyle(
                              fontSize: _bodyFontSize,
                              height: 1.6,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                  // ESV 구절
                  if (_currentTranslation == Translation.esv ||
                      _currentTranslation == Translation.compare)
                    Padding(
                      padding: _currentTranslation == Translation.compare
                          ? const EdgeInsets.only(top: 8)
                          : EdgeInsets.zero,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentTranslation == Translation.esv)
                            Text(
                              '${verse.verseNumber}',
                              style: TextStyle(
                                fontSize: _bodyFontSize - 2,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (_currentTranslation == Translation.esv)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              esvVerse.text.isNotEmpty
                                  ? esvVerse.text
                                  : '(ESV translation not available)',
                              style: TextStyle(
                                fontSize: _bodyFontSize - 1,
                                height: 1.6,
                                color: _currentTranslation == Translation.compare
                                    ? Colors.grey[700]
                                    : Colors.black87,
                                fontStyle: _currentTranslation == Translation.compare
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _hasSelectedVerses() {
    return _selectedVerses.isNotEmpty;
  }

  double _getButtonOpacity() {
    if (_scrollProgress < 0.9) {
      return 1.0;
    } else {
      final normalizedProgress = (_scrollProgress - 0.9) / 0.1;
      return 1.0 - (normalizedProgress * 0.5);
    }
  }

  Widget _buildFloatingActionButtons() {
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
                  heroTag: 'copy_bible',
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

          // 하이라이트 버튼 (확장 시, 비로그인 시 반투명)
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ScaleTransition(
                scale: _expandAnimation,
                child: Opacity(
                  opacity: isLoggedIn ? 1.0 : 0.4,
                  child: FloatingActionButton(
                    heroTag: 'highlight_bible',
                    onPressed: () {
                      if (isLoggedIn) {
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _startHighlight();
                      } else {
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _showLoginPrompt(isHighlight: true);
                      }
                    },
                    backgroundColor: Colors.green,
                    child: const Icon(
                      Icons.highlight,
                      color: Colors.white,
                      size: 24,
                    ),
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
                    heroTag: 'meditation_bible',
                    onPressed: () {
                      if (isLoggedIn) {
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _startMeditation();
                      } else {
                        setState(() {
                          _isExpanded = false;
                          _expandController.reverse();
                        });
                        _showLoginPrompt(isHighlight: false);
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
            heroTag: 'main_bible',
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                      '/login',
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
        _selectedVerses.clear();
      });
    }
  }

  Future<void> _startMeditation() async {
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

    final selectedVerses = await showDialog<List<VerseReference>>(
      context: context,
      builder: (context) => VerseSelectionDialog(
        availableVerses: verses,
      ),
    );

    if (selectedVerses == null || selectedVerses.isEmpty) return;

    final content = await showDialog<String>(
      context: context,
      builder: (context) => MeditationWritingDialog(
        selectedVerses: selectedVerses,
      ),
    );

    if (content == null || content.isEmpty) return;

    final color = await showDialog<String>(
      context: context,
      builder: (context) => const ColorSelectionDialog(),
    );

    if (color == null) return;

    await _saveMeditation(selectedVerses, content, color);
  }

  Future<List<VerseReference>> _getSelectedVerseReferences() async {
    final List<VerseReference> verses = [];
    
    for (var key in _selectedVerses) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final book = parts[0];
        final chapter = int.parse(parts[1]);
        final verseNum = int.parse(parts[2]);
        
        final verseText = BibleService().getVerses(book, chapter, chapter)
            .firstWhere((v) => v.verseNumber == verseNum, 
                orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''))
            .text;
        
        verses.add(VerseReference(
          book: book,
          chapter: chapter,
          verse: verseNum,
          text: verseText,
        ));
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

  // 하이라이트를 묵상으로 전환
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
              _selectedVerses.clear();
            });
          }
        },
      ),
    );
  }

  Future<String> _getKoreanFormat() async {
    final List<SelectedVerse> allSelected = [];

    for (var key in _selectedVerses) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final book = parts[0];
        final chapter = int.parse(parts[1]);
        final verseNum = int.parse(parts[2]);

        final verse = BibleService().getVerses(book, chapter, chapter)
            .firstWhere((v) => v.verseNumber == verseNum,
                orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''));

        if (verse.text.isNotEmpty) {
          allSelected.add(SelectedVerse(
            book: book,
            fullName: _currentBook.koreanName,
            chapter: chapter,
            verseNumber: verseNum,
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

    for (var key in _selectedVerses) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final chapter = int.parse(parts[1]);
        final verseNum = int.parse(parts[2]);

        final esvVerse = BibleService().getEsvVerses(_currentBook.englishShort, chapter, chapter)
            .firstWhere((v) => v.verseNumber == verseNum,
                orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''));

        if (esvVerse.text.isNotEmpty) {
          allSelected.add(SelectedVerseEsv(
            bookEng: _currentBook.englishShort,
            fullNameEng: _currentBook.englishName,
            chapter: chapter,
            verseNumber: verseNum,
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

    for (var key in _selectedVerses) {
      final parts = key.split('-');
      if (parts.length == 3) {
        final book = parts[0];
        final chapter = int.parse(parts[1]);
        final verseNum = int.parse(parts[2]);

        final koreanVerse = BibleService().getVerses(book, chapter, chapter)
            .firstWhere((v) => v.verseNumber == verseNum,
                orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''));

        final esvVerse = BibleService().getEsvVerses(_currentBook.englishShort, chapter, chapter)
            .firstWhere((v) => v.verseNumber == verseNum,
                orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''));

        if (koreanVerse.text.isNotEmpty) {
          allSelected.add(SelectedVerseCompare(
            book: book,
            fullName: _currentBook.koreanName,
            chapter: chapter,
            verseNumber: verseNum,
            koreanText: koreanVerse.text,
            englishText: esvVerse.text,
          ));
        }
      }
    }

    final formattedText = BibleService().formatSelectedVersesCompare(allSelected);
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<void> _showBibleSelectionDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const BibleSelectionDialog(),
    );

    if (result != null && mounted) {
      final targetVerse = result['verse'] as int?;
      
      // 같은 책의 다른 장으로 이동하는 경우
      if (result['book'] == _currentBook.koreanShort) {
        final targetChapter = result['chapter'] as int;
        
        await _pageController.animateToPage(
          targetChapter - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        
        setState(() {
          _currentChapter = targetChapter;
          _selectedVerses.clear();
        });
        await _loadMeditations();
        
        if (targetVerse != null) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _scrollToVerse(targetVerse);
            }
          });
        }
      } else {
        // 다른 책으로 이동하는 경우
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BibleReaderScreen(
              bookShort: result['book'],
              bookName: result['bookName'],
              bookEng: result['bookEng'],
              initialChapter: result['chapter'],
              initialVerse: targetVerse,
              autoShowDialog: false,  // 다시 진입할 때는 자동 다이얼로그 표시 안 함
            ),
          ),
        );
      }
    }
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

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    _expandController.dispose();
    super.dispose();
  }
}