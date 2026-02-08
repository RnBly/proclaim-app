/**
 * bible_reader_screen.dart
 * 
 * 성경 전체 읽기 화면
 * 
 * 주요 기능:
 * - 성경 66권 전체를 장 단위로 읽기
 * - 책/장 선택 다이얼로그
 * - 역본 전환 (한글/ESV/대조)
 * - 구절 선택 및 복사
 * - 묵상 작성
 * - 하이라이트 기능
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../services/auth_service.dart';
import '../services/meditation_service.dart';
import '../services/preferences_service.dart';
import '../models/bible_reading.dart';
import '../models/meditation.dart';
import '../widgets/translation_dialog.dart';
import '../widgets/meditation_writing_dialog.dart';
import '../widgets/meditation_view_dialog.dart';
import '../widgets/color_selection_dialog.dart';
import '../widgets/verse_selection_dialog.dart';
import '../widgets/copy_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/meditation_action_buttons.dart';
import '../widgets/highlight_options_dialog.dart';
import 'login_screen.dart';

class BibleReaderScreen extends StatefulWidget {
  final String bookShort;
  final String bookName;
  final String bookEng;
  final int initialChapter;
  final bool autoShowDialog;

  const BibleReaderScreen({
    super.key,
    required this.bookShort,
    required this.bookName,
    required this.bookEng,
    this.initialChapter = 1,
    this.autoShowDialog = false,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late String _currentBookShort;
  late String _currentBookName;
  late String _currentBookEng;
  late int _currentChapter;
  
  Translation _currentTranslation = Translation.korean;
  
  double _titleFontSize = 24.0;
  double _bodyFontSize = 18.0;

  final Set<String> _selectedVerses = {};
  Map<String, String> _highlightedVerses = {};

  List<Verse> _verses = [];
  List<Verse> _esvVerses = [];

  @override
  void initState() {
    super.initState();
    _currentBookShort = widget.bookShort;
    _currentBookName = widget.bookName;
    _currentBookEng = widget.bookEng;
    _currentChapter = widget.initialChapter;
    
    _loadSavedPreferences();
    _loadVerses();
    _loadMeditations();

    if (widget.autoShowDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showBibleSelectionDialog();
          }
        });
      });
    }
  }

  Future<void> _loadSavedPreferences() async {
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

    if (mounted) {
      setState(() {
        _highlightedVerses = highlights;
      });
    }
  }

  void _loadVerses() {
    final koreanVerses = BibleService().getVerses(
      _currentBookShort,
      _currentChapter,
      _currentChapter,
    );

    final esvVerses = BibleService().getEsvVerses(
      _currentBookEng,
      _currentChapter,
      _currentChapter,
    );

    setState(() {
      _verses = koreanVerses;
      _esvVerses = esvVerses;
      _selectedVerses.clear();
    });
  }

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

  void _showBibleSelectionDialog() {
    // 성경 책/장 선택 다이얼로그
    // 실제 구현은 별도의 위젯으로 분리 가능
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('성경 선택'),
        content: const Text('성경 선택 기능은 별도 구현이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
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
            _selectedVerses.clear();
          });
          final prefs = PreferencesService();
          if (translation == Translation.korean) {
            prefs.saveTranslation('korean');
          } else if (translation == Translation.esv) {
            prefs.saveTranslation('esv');
          } else if (translation == Translation.compare) {
            prefs.saveTranslation('compare');
          }
          _loadVerses();
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

  void _previousChapter() {
    if (_currentChapter > 1) {
      setState(() {
        _currentChapter--;
      });
      _loadVerses();
    }
  }

  void _nextChapter() {
    setState(() {
      _currentChapter++;
    });
    _loadVerses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _showBibleSelectionDialog,
          child: Text(
            '$_currentBookName $_currentChapter장',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 장 네비게이션
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: _currentChapter > 1 ? Colors.black87 : Colors.grey[400],
                  ),
                  onPressed: _currentChapter > 1 ? _previousChapter : null,
                ),
                Text(
                  '$_currentChapter장',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.black87),
                  onPressed: _nextChapter,
                ),
              ],
            ),
          ),

          // 본문
          Expanded(
            child: _buildVerseList(),
          ),
        ],
      ),
      floatingActionButton: _hasSelectedVerses()
          ? MeditationActionButtons(
              heroTagPrefix: 'reader',
              onCopyPressed: _copySelectedVerses,
              onHighlightPressed: _startHighlight,
              onMeditationPressed: _startMeditation,
              onLoginPrompt: _showLoginPrompt,
            )
          : null,
    );
  }

  Widget _buildVerseList() {
    if (_verses.isEmpty) {
      return const Center(
        child: Text('본문을 불러올 수 없습니다'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _verses.length,
      itemBuilder: (context, index) {
        final verse = _verses[index];
        final isSelected = _selectedVerses.contains(verse.key);
        final highlightKey = '${verse.book}-${verse.chapter}-${verse.verseNumber}';
        final highlightColor = _highlightedVerses[highlightKey];

        return _buildVerseItem(verse, isSelected, highlightColor);
      },
    );
  }

  Widget _buildVerseItem(Verse verse, bool isSelected, String? highlightColor) {
    Color? backgroundColor;
    if (highlightColor != null) {
      backgroundColor = _getHighlightColor(highlightColor);
    } else if (isSelected) {
      backgroundColor = Colors.blue[50];
    }

    return GestureDetector(
      onTap: () {
        if (highlightColor != null) {
          _viewMeditation(verse.book, verse.chapter, verse.verseNumber);
        } else {
          _toggleVerse(verse.key);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: _buildVerseContent(verse),
      ),
    );
  }

  Widget _buildVerseContent(Verse verse) {
    if (_currentTranslation == Translation.korean) {
      return _buildKoreanVerse(verse);
    } else if (_currentTranslation == Translation.esv) {
      return _buildEsvVerse(verse);
    } else {
      return _buildCompareVerse(verse);
    }
  }

  Widget _buildKoreanVerse(Verse verse) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${verse.verseNumber}. ',
            style: TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          TextSpan(
            text: verse.text,
            style: TextStyle(
              fontSize: _bodyFontSize,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEsvVerse(Verse verse) {
    final esvVerse = _esvVerses.firstWhere(
      (v) => v.verseNumber == verse.verseNumber,
      orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
    );

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${verse.verseNumber}. ',
            style: TextStyle(
              fontSize: _bodyFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          TextSpan(
            text: esvVerse.text,
            style: TextStyle(
              fontSize: _bodyFontSize,
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareVerse(Verse verse) {
    final esvVerse = _esvVerses.firstWhere(
      (v) => v.verseNumber == verse.verseNumber,
      orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 절 번호
        Text(
          '${verse.verseNumber}.',
          style: TextStyle(
            fontSize: _bodyFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        const SizedBox(height: 4),
        // 한글
        Text(
          verse.text,
          style: TextStyle(
            fontSize: _bodyFontSize,
            color: Colors.black87,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        // ESV
        Text(
          esvVerse.text,
          style: TextStyle(
            fontSize: _bodyFontSize * 0.95,
            color: Colors.grey[700],
            height: 1.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Color _getHighlightColor(String colorName) {
    switch (colorName) {
      case 'yellow':
        return Colors.yellow[100]!;
      case 'green':
        return Colors.green[100]!;
      case 'blue':
        return Colors.blue[100]!;
      case 'purple':
        return Colors.purple[100]!;
      case 'pink':
        return Colors.pink[100]!;
      default:
        return Colors.grey[100]!;
    }
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

  // 묵상 시작
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

  // 선택된 구절들을 VerseReference로 변환
  Future<List<VerseReference>> _getSelectedVerseReferences() async {
    final List<VerseReference> verses = [];

    for (var verse in _verses) {
      if (_selectedVerses.contains(verse.key)) {
        verses.add(VerseReference(
          book: verse.book,
          chapter: verse.chapter,
          verse: verse.verseNumber,
          text: verse.text,
        ));
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

  // 복사
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

    for (var verse in _verses) {
      if (_selectedVerses.contains(verse.key)) {
        allSelected.add(SelectedVerse(
          book: verse.book,
          fullName: _currentBookName,
          chapter: verse.chapter,
          verseNumber: verse.verseNumber,
          text: verse.text,
        ));
      }
    }

    final formattedText = BibleService().formatSelectedVerses(allSelected);
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    for (var verse in _verses) {
      if (_selectedVerses.contains(verse.key)) {
        final esvVerse = _esvVerses.firstWhere(
          (v) => v.verseNumber == verse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );

        if (esvVerse.text.isNotEmpty) {
          allSelected.add(SelectedVerseEsv(
            bookEng: _currentBookEng,
            fullNameEng: _currentBookName,
            chapter: verse.chapter,
            verseNumber: verse.verseNumber,
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

    for (var verse in _verses) {
      if (_selectedVerses.contains(verse.key)) {
        final esvVerse = _esvVerses.firstWhere(
          (v) => v.verseNumber == verse.verseNumber,
          orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
        );

        allSelected.add(SelectedVerseCompare(
          book: verse.book,
          fullName: _currentBookName,
          chapter: verse.chapter,
          verseNumber: verse.verseNumber,
          koreanText: verse.text,
          englishText: esvVerse.text,
        ));
      }
    }

    final formattedText = BibleService().formatSelectedVersesCompare(allSelected);
    
    return '$formattedText\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
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
}