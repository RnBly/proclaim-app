import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../models/bible_reading.dart';
import '../widgets/bible_page.dart';
import '../widgets/date_picker_dialog.dart' as custom;
import '../widgets/translation_dialog.dart';
import '../widgets/copy_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime _selectedDate = DateTime.now();
  Translation _currentTranslation = Translation.korean;
  final Map<String, Set<String>> _selectedVerses = {
    'old': {},
    'psalms': {},
    'new': {},
  };

  @override
  Widget build(BuildContext context) {
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
                '오늘의 성경 말씀($dateStr)',
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
                  icon: const Icon(Icons.translate, color: Colors.black87),
                  onPressed: _showTranslationDialog,
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
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        children: [
          BiblePage(
            sheetType: 'old',
            selectedDate: _selectedDate,
            translation: _currentTranslation,
            selectedVerses: _selectedVerses['old']!,
            onVerseToggle: (key) => _toggleVerse('old', key),
          ),
          BiblePage(
            sheetType: 'psalms',
            selectedDate: _selectedDate,
            translation: _currentTranslation,
            selectedVerses: _selectedVerses['psalms']!,
            onVerseToggle: (key) => _toggleVerse('psalms', key),
          ),
          BiblePage(
            sheetType: 'new',
            selectedDate: _selectedDate,
            translation: _currentTranslation,
            selectedVerses: _selectedVerses['new']!,
            onVerseToggle: (key) => _toggleVerse('new', key),
          ),
        ],
      ),
      floatingActionButton: _hasSelectedVerses()
          ? FloatingActionButton(
        onPressed: _copySelectedVerses,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.copy, color: Colors.white),
      )
          : null,
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

  void _showTranslationDialog() {
    showDialog(
      context: context,
      builder: (context) => TranslationDialog(
        currentTranslation: _currentTranslation,
        onTranslationChanged: (translation) {
          setState(() {
            _currentTranslation = translation;
            _selectedVerses['old']!.clear();
            _selectedVerses['psalms']!.clear();
            _selectedVerses['new']!.clear();
          });
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

  Future<void> _copySelectedVerses() async {
    // 복사 형식 선택 다이얼로그 표시
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
      final reading = BibleService().getReadingForDate(_selectedDate, sheetType);
      if (reading == null) continue;

      final verses = BibleService().getVerses(
        reading.book,
        reading.startChapter,
        reading.endChapter,
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

    return BibleService().formatSelectedVerses(allSelected);
  }

  Future<String> _getEsvFormat() async {
    final List<SelectedVerseEsv> allSelected = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final reading = BibleService().getReadingForDate(_selectedDate, sheetType);
      if (reading == null) continue;

      // 한글 구절과 ESV 구절 모두 가져오기
      final koreanVerses = BibleService().getVerses(
        reading.book,
        reading.startChapter,
        reading.endChapter,
      );

      final esvVerses = BibleService().getEsvVerses(
        reading.bookEng,
        reading.startChapter,
        reading.endChapter,
      );

      // 한글 key로 선택된 것 확인
      for (var koreanVerse in koreanVerses) {
        if (_selectedVerses[sheetType]!.contains(koreanVerse.key)) {
          // 해당하는 ESV 구절 찾기
          final esvVerse = esvVerses.firstWhere(
                (v) => v.chapter == koreanVerse.chapter && v.verseNumber == koreanVerse.verseNumber,
            orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
          );

          if (esvVerse.text.isNotEmpty) {
            allSelected.add(SelectedVerseEsv(
              bookEng: reading.bookEng,  // 약칭 사용
              fullNameEng: reading.fullNameEng,
              chapter: esvVerse.chapter,
              verseNumber: esvVerse.verseNumber,
              text: esvVerse.text,
            ));
          }
        }
      }
    }

    return BibleService().formatSelectedVersesEsv(allSelected);
  }

  Future<String> _getCompareFormat() async {
    final List<SelectedVerseCompare> allSelected = [];

    for (var sheetType in ['old', 'psalms', 'new']) {
      final reading = BibleService().getReadingForDate(_selectedDate, sheetType);
      if (reading == null) continue;

      final koreanVerses = BibleService().getVerses(
        reading.book,
        reading.startChapter,
        reading.endChapter,
      );

      final esvVerses = BibleService().getEsvVerses(
        reading.bookEng,
        reading.startChapter,
        reading.endChapter,
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

    return BibleService().formatSelectedVersesCompare(allSelected);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
