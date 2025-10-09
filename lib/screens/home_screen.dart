import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/bible_service.dart';
import '../models/bible_reading.dart';
import '../widgets/bible_page.dart';
import '../widgets/date_picker_dialog.dart' as custom;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  DateTime _selectedDate = DateTime.now();  // 이 줄이 있어야 합니다!
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
            selectedVerses: _selectedVerses['old']!,
            onVerseToggle: (key) => _toggleVerse('old', key),
          ),
          BiblePage(
            sheetType: 'psalms',
            selectedDate: _selectedDate,
            selectedVerses: _selectedVerses['psalms']!,
            onVerseToggle: (key) => _toggleVerse('psalms', key),
          ),
          BiblePage(
            sheetType: 'new',
            selectedDate: _selectedDate,
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
            // 날짜 변경 시 선택된 절 초기화
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

    final formatted = BibleService().formatSelectedVerses(allSelected);

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}