/**
 * bible_selection_dialog.dart
 * 
 * 성경 66권 중 원하는 책/장/절을 선택하는 다이얼로그
 * 
 * 주요 기능:
 * - 3단 선택 방식 (책 → 장 → 절)
 * - 구약: 검은색, 신약: 빨간색으로 구분
 * - 시편은 "편" 표기
 * - 절 선택 시 자동으로 다이얼로그 닫기
 */

import 'package:flutter/material.dart';
import '../models/bible_book.dart';
import '../services/bible_service.dart';

class BibleSelectionDialog extends StatefulWidget {
  final String? initialBook;     // 초기 선택 책 (약어)
  final int? initialChapter;     // 초기 선택 장
  
  const BibleSelectionDialog({
    super.key,
    this.initialBook,
    this.initialChapter,
  });

  @override
  State<BibleSelectionDialog> createState() => _BibleSelectionDialogState();
}

class _BibleSelectionDialogState extends State<BibleSelectionDialog> {
  BibleBook? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;

  final List<BibleBook> _allBooks = BibleBook.getAllBooks();
  final ScrollController _bookScrollController = ScrollController();
  final ScrollController _chapterScrollController = ScrollController();
  final ScrollController _verseScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // 초기값 설정: 전달받은 값이 있으면 사용, 없으면 창세기 1장
    if (widget.initialBook != null) {
      _selectedBook = _allBooks.firstWhere(
        (book) => book.koreanShort == widget.initialBook,
        orElse: () => _allBooks.first,
      );
    } else {
      _selectedBook = _allBooks.first;
    }
    
    _selectedChapter = widget.initialChapter ?? 1;
    _loadVerseCount();
  }

  // 선택된 장의 절 수 로드
  Future<void> _loadVerseCount() async {
    if (_selectedBook == null || _selectedChapter == null) return;

    final verses = BibleService().getVerses(
      _selectedBook!.koreanShort,
      _selectedChapter!,
      _selectedChapter!,
    );

    if (mounted && verses.isNotEmpty) {
      setState(() {
        // 절 수가 바뀌면 1절로 리셋
        _selectedVerse = 1;
      });
    }
  }

  // 현재 선택된 장의 총 절 수 반환
  int _getVerseCount() {
    if (_selectedBook == null || _selectedChapter == null) return 0;

    final verses = BibleService().getVerses(
      _selectedBook!.koreanShort,
      _selectedChapter!,
      _selectedChapter!,
    );

    return verses.isEmpty ? 0 : verses.last.verseNumber;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.7; // 화면의 70% 높이

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: dialogHeight,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '성경 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 3단 선택 영역
            Expanded(
              child: Row(
                children: [
                  // 1단: 성경책 리스트
                  Expanded(
                    flex: 3,
                    child: _buildBookList(),
                  ),
                  const SizedBox(width: 8),

                  // 2단: 장 선택
                  Expanded(
                    flex: 2,
                    child: _buildChapterList(),
                  ),
                  const SizedBox(width: 8),

                  // 3단: 절 선택
                  Expanded(
                    flex: 2,
                    child: _buildVerseList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 성경책 리스트 (구약/신약 구분)
  Widget _buildBookList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _bookScrollController,
        itemCount: _allBooks.length,
        itemBuilder: (context, index) {
          final book = _allBooks[index];
          final isSelected = _selectedBook == book;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedBook = book;
                _selectedChapter = 1;
                _loadVerseCount();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Text(
                book.koreanName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: book.isOldTestament ? Colors.black87 : Colors.red[700],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 장 선택 리스트
  Widget _buildChapterList() {
    if (_selectedBook == null) return const SizedBox();

    final isPsalms = _selectedBook!.koreanShort == '시'; // 시편인지 확인
    final unit = isPsalms ? '편' : '장';

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _chapterScrollController,
        itemCount: _selectedBook!.totalChapters,
        itemBuilder: (context, index) {
          final chapterNum = index + 1;
          final isSelected = _selectedChapter == chapterNum;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedChapter = chapterNum;
                _loadVerseCount();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Text(
                '$chapterNum$unit',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 절 선택 리스트
  Widget _buildVerseList() {
    if (_selectedBook == null || _selectedChapter == null) {
      return const SizedBox();
    }

    final verseCount = _getVerseCount();

    if (verseCount == 0) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text('절 정보 없음'),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        controller: _verseScrollController,
        itemCount: verseCount,
        itemBuilder: (context, index) {
          final verseNum = index + 1;
          final isSelected = _selectedVerse == verseNum;

          return InkWell(
            onTap: () {
              // 절 선택 시 즉시 결과 반환하고 다이얼로그 닫기
              Navigator.pop(context, {
                'book': _selectedBook!.koreanShort,
                'bookName': _selectedBook!.koreanName,
                'bookEng': _selectedBook!.englishShort,
                'chapter': _selectedChapter!,
                'verse': verseNum,
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Text(
                '$verseNum절',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _bookScrollController.dispose();
    _chapterScrollController.dispose();
    _verseScrollController.dispose();
    super.dispose();
  }
}