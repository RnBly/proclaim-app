/**
 * meditation_view_dialog.dart
 * 
 * 저장된 묵상을 보여주는 다이얼로그
 * 
 * 기능:
 * - 묵상 내용 표시
 * - 관련 성경 구절 표시 (하이라이트 포함)
 * - 생성/수정 시간 표시
 * - 묵상 삭제 버튼
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/meditation.dart';
import '../models/bible_reading.dart';
import '../services/bible_service.dart';
import 'copy_dialog.dart';

// 묵상 조회 다이얼로그
class MeditationViewDialog extends StatefulWidget {
  final List<Meditation> meditations; // 해당 구절의 모든 묵상들
  final int initialIndex; // 초기 표시할 묵상 인덱스
  final Function(Meditation)? onEdit; // 수정 콜백
  final Function(String)? onDelete; // 삭제 콜백

  const MeditationViewDialog({
    super.key,
    required this.meditations,
    this.initialIndex = 0,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<MeditationViewDialog> createState() => _MeditationViewDialogState();
}

class _MeditationViewDialogState extends State<MeditationViewDialog> {
  late int _currentIndex;
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Meditation get _currentMeditation => widget.meditations[_currentIndex];

  String _formatDate(DateTime date) {
    return DateFormat('M월 d일').format(date);
  }

  // 한글 책이름 → 영어 책이름 매핑
  final Map<String, String> _bookMapping = {
    '창': 'Gen', '출': 'Exo', '레': 'Lev', '민': 'Num', '신': 'Deu',
    '수': 'Jos', '삿': 'Jdg', '룻': 'Rut', '삼상': '1Sa', '삼하': '2Sa',
    '왕상': '1Ki', '왕하': '2Ki', '대상': '1Ch', '대하': '2Ch',
    '스': 'Ezr', '느': 'Neh', '에': 'Est', '욥': 'Job', '시': 'Psa',
    '잠': 'Pro', '전': 'Ecc', '아': 'Sgs', '사': 'Isa', '렘': 'Jer',
    '애': 'Lam', '겔': 'Eze', '단': 'Dan', '호': 'Hos', '욜': 'Joe',
    '암': 'Amo', '옵': 'Oba', '욘': 'Jon', '미': 'Mic', '나': 'Nah',
    '합': 'Hab', '습': 'Zep', '학': 'Hag', '슥': 'Zec', '말': 'Mal',
    '마': 'Mat', '막': 'Mar', '눅': 'Luk', '요': 'Joh', '행': 'Act',
    '롬': 'Rom', '고전': '1Co', '고후': '2Co', '갈': 'Gal', '엡': 'Eph',
    '빌': 'Phi', '골': 'Col', '살전': '1Th', '살후': '2Th',
    '딤전': '1Ti', '딤후': '2Ti', '딛': 'Tit', '몬': 'Phm', '히': 'Heb',
    '약': 'Jam', '벧전': '1Pe', '벧후': '2Pe', '요일': '1Jo',
    '요이': '2Jo', '요삼': '3Jo', '유': 'Jud', '계': 'Rev',
  };

  // 한글 전체 책이름 매핑
  final Map<String, String> _fullNameMapping = {
    '창': '창세기', '출': '출애굽기', '레': '레위기', '민': '민수기', '신': '신명기',
    '수': '여호수아', '삿': '사사기', '룻': '룻기', '삼상': '사무엘상', '삼하': '사무엘하',
    '왕상': '열왕기상', '왕하': '열왕기하', '대상': '역대상', '대하': '역대하',
    '스': '에스라', '느': '느헤미야', '에': '에스더', '욥': '욥기', '시': '시편',
    '잠': '잠언', '전': '전도서', '아': '아가', '사': '이사야', '렘': '예레미야',
    '애': '예레미야애가', '겔': '에스겔', '단': '다니엘', '호': '호세아', '욜': '요엘',
    '암': '아모스', '옵': '오바댜', '욘': '요나', '미': '미가', '나': '나훔',
    '합': '하박국', '습': '스바냐', '학': '학개', '슥': '스가랴', '말': '말라기',
    '마': '마태복음', '막': '마가복음', '눅': '누가복음', '요': '요한복음', '행': '사도행전',
    '롬': '로마서', '고전': '고린도전서', '고후': '고린도후서', '갈': '갈라디아서', '엡': '에베소서',
    '빌': '빌립보서', '골': '골로새서', '살전': '데살로니가전서', '살후': '데살로니가후서',
    '딤전': '디모데전서', '딤후': '디모데후서', '딛': '디도서', '몬': '빌레몬서', '히': '히브리서',
    '약': '야고보서', '벧전': '베드로전서', '벧후': '베드로후서', '요일': '요한일서',
    '요이': '요한이서', '요삼': '요한삼서', '유': '유다서', '계': '요한계시록',
  };

  // 영어 전체 책이름 매핑
  final Map<String, String> _fullNameEngMapping = {
    'Gen': 'Genesis', 'Exo': 'Exodus', 'Lev': 'Leviticus', 'Num': 'Numbers', 'Deu': 'Deuteronomy',
    'Jos': 'Joshua', 'Jdg': 'Judges', 'Rut': 'Ruth', '1Sa': '1 Samuel', '2Sa': '2 Samuel',
    '1Ki': '1 Kings', '2Ki': '2 Kings', '1Ch': '1 Chronicles', '2Ch': '2 Chronicles',
    'Ezr': 'Ezra', 'Neh': 'Nehemiah', 'Est': 'Esther', 'Job': 'Job', 'Psa': 'Psalms',
    'Pro': 'Proverbs', 'Ecc': 'Ecclesiastes', 'Sgs': 'Song of Songs', 'Isa': 'Isaiah', 'Jer': 'Jeremiah',
    'Lam': 'Lamentations', 'Eze': 'Ezekiel', 'Dan': 'Daniel', 'Hos': 'Hosea', 'Joe': 'Joel',
    'Amo': 'Amos', 'Oba': 'Obadiah', 'Jon': 'Jonah', 'Mic': 'Micah', 'Nah': 'Nahum',
    'Hab': 'Habakkuk', 'Zep': 'Zephaniah', 'Hag': 'Haggai', 'Zec': 'Zechariah', 'Mal': 'Malachi',
    'Mat': 'Matthew', 'Mar': 'Mark', 'Luk': 'Luke', 'Joh': 'John', 'Act': 'Acts',
    'Rom': 'Romans', '1Co': '1 Corinthians', '2Co': '2 Corinthians', 'Gal': 'Galatians', 'Eph': 'Ephesians',
    'Phi': 'Philippians', 'Col': 'Colossians', '1Th': '1 Thessalonians', '2Th': '2 Thessalonians',
    '1Ti': '1 Timothy', '2Ti': '2 Timothy', 'Tit': 'Titus', 'Phm': 'Philemon', 'Heb': 'Hebrews',
    'Jam': 'James', '1Pe': '1 Peter', '2Pe': '2 Peter', '1Jo': '1 John',
    '2Jo': '2 John', '3Jo': '3 John', 'Jud': 'Jude', 'Rev': 'Revelation',
  };

  // 본문(구절) 복사 함수 - 버전 선택 다이얼로그 추가
  void _copyVerses() async {
    print('🔵 _copyVerses 함수 시작!');
    print('🔵 현재 묵상 구절 수: ${_currentMeditation.verses.length}');
    
    // 1. 복사 형식 선택 다이얼로그 표시
    print('🔵 CopyDialog 표시 시작...');
    showDialog(
      context: context,
      builder: (dialogContext) => CopyDialog(
        onFormatSelected: (format) async {
          print('🟢 CopyDialog에서 선택됨: $format');
          Navigator.pop(dialogContext);
          
          await _performCopy(format);
        },
      ),
    );
  }

  Future<void> _performCopy(CopyFormat format) async {
    print('🔵 선택된 format: $format');

    String formattedText = '';

    try {
      print('🔵 포맷팅 시작: $format');
      if (format == CopyFormat.korean) {
        print('🔵 한글 버전 포맷팅 시작');
        formattedText = _formatKorean();
        print('🔵 한글 포맷팅 완료: ${formattedText.length}자');
      } else if (format == CopyFormat.esv) {
        print('🔵 영어 버전 포맷팅 시작');
        formattedText = await _formatEsv();
        print('🔵 영어 포맷팅 완료: ${formattedText.length}자');
      } else {
        print('🔵 대조 버전 포맷팅 시작');
        formattedText = await _formatCompare();
        print('🔵 대조 포맷팅 완료: ${formattedText.length}자');
      }

      print('📋 최종 복사 내용 (처음 200자):');
      print(formattedText.substring(0, formattedText.length > 200 ? 200 : formattedText.length));
      print('...');

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: formattedText));
      print('✅ 클립보드 복사 완료!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('본문이 복사되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌❌❌ 복사 오류 발생!');
      print('오류: $e');
      print('스택트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('복사 중 오류 발생: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 한글 버전 포맷팅
  String _formatKorean() {
    print('📝 _formatKorean 시작');
    final verses = _currentMeditation.verses;
    print('📝 구절 수: ${verses.length}');
    
    final selectedVerses = verses.map((v) {
      print('📝 구절 변환: ${v.book} ${v.chapter}:${v.verse}');
      return SelectedVerse(
        book: v.book,
        fullName: _fullNameMapping[v.book] ?? v.book,
        chapter: v.chapter,
        verseNumber: v.verse,
        text: v.text,
      );
    }).toList();

    print('📝 BibleService().formatSelectedVerses 호출');
    final result = BibleService().formatSelectedVerses(selectedVerses);
    print('📝 포맷팅 결과 길이: ${result.length}');
    
    // 앱 링크 추가
    return '$result\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  // 영어 버전 포맷팅
  Future<String> _formatEsv() async {
    final verses = _currentMeditation.verses;
    final List<SelectedVerseEsv> selectedVerses = [];

    for (var v in verses) {
      final bookEng = _bookMapping[v.book];
      if (bookEng == null) continue;

      // ESV 텍스트 가져오기
      final esvVerses = BibleService().getEsvVerses(
        bookEng,
        v.chapter,
        v.chapter,
      );

      final esvVerse = esvVerses.firstWhere(
        (ev) => ev.chapter == v.chapter && ev.verseNumber == v.verse,
        orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
      );

      if (esvVerse.text.isNotEmpty) {
        selectedVerses.add(SelectedVerseEsv(
          bookEng: bookEng,
          fullNameEng: _fullNameEngMapping[bookEng] ?? bookEng,
          chapter: v.chapter,
          verseNumber: v.verse,
          text: esvVerse.text,
        ));
      }
    }

    final result = BibleService().formatSelectedVersesEsv(selectedVerses);
    
    // 앱 링크 추가
    return '$result\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  // 대조 버전 포맷팅
  Future<String> _formatCompare() async {
    final verses = _currentMeditation.verses;
    final List<SelectedVerseCompare> selectedVerses = [];

    for (var v in verses) {
      final bookEng = _bookMapping[v.book];
      if (bookEng == null) continue;

      // ESV 텍스트 가져오기
      final esvVerses = BibleService().getEsvVerses(
        bookEng,
        v.chapter,
        v.chapter,
      );

      final esvVerse = esvVerses.firstWhere(
        (ev) => ev.chapter == v.chapter && ev.verseNumber == v.verse,
        orElse: () => Verse(book: '', chapter: 0, verseNumber: 0, text: ''),
      );

      selectedVerses.add(SelectedVerseCompare(
        book: v.book,
        fullName: _fullNameMapping[v.book] ?? v.book,
        chapter: v.chapter,
        verseNumber: v.verse,
        koreanText: v.text,
        englishText: esvVerse.text,
      ));
    }

    final result = BibleService().formatSelectedVersesCompare(selectedVerses);
    
    // 앱 링크 추가
    return '$result\n\n👇오늘의 말씀읽기👇\nhttps://rnbly.github.io/proclaim-app/';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 날짜 (여러 묵상이 있는 경우 드롭다운)
                Expanded(
                  child: widget.meditations.length > 1
                      ? _buildDateDropdown()
                      : Text(
                    _buildDateLabel(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 선택된 구절들 - 복사 가능하게 수정
            Expanded(
              flex: 2, // 전체의 약 2/5
              child: InkWell(
                onTap: _copyVerses,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    children: [
                      // 구절 내용
                      Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _currentMeditation.verses.map((verse) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildVerseItem(verse),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      // 오른쪽 위 복사 아이콘
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.content_copy, size: 18),
                          color: Colors.grey.shade600,
                          onPressed: _copyVerses,
                          tooltip: '본문 복사',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 묵상 내용 섹션
            const Text(
              '나의 묵상',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 묵상 내용 - Expanded로 남은 공간 사용
            Expanded(
              flex: 3, // 전체의 약 3/5
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Scrollbar(
                  controller: _contentScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _contentScrollController,
                    child: Text(
                      _currentMeditation.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 삭제/수정 버튼
            Row(
              children: [
                // 삭제 버튼
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete?.call(_currentMeditation.id);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 수정 버튼
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        // onEdit을 먼저 호출 (다이얼로그는 onEdit 내부에서 닫음)
                        widget.onEdit?.call(_currentMeditation);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE6E26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '수정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDropdown() {
    return PopupMenuButton<int>(
      initialValue: _currentIndex,
      onSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_drop_down, size: 24),
            const SizedBox(width: 4),
            Text(
              _buildDateLabel(_currentIndex),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        // 날짜별로 그룹화
        final dateGroups = <String, List<int>>{};
        for (int i = 0; i < widget.meditations.length; i++) {
          final dateStr = _formatDate(widget.meditations[i].createdAt);
          if (!dateGroups.containsKey(dateStr)) {
            dateGroups[dateStr] = [];
          }
          dateGroups[dateStr]!.add(i);
        }

        return List.generate(widget.meditations.length, (index) {
          return PopupMenuItem<int>(
            value: index,
            child: Text(_buildDateLabel(index)),
          );
        });
      },
    );
  }

  String _buildDateLabel(int index) {
    final meditation = widget.meditations[index];
    final dateStr = _formatDate(meditation.createdAt);

    // 같은 날짜의 묵상들 찾기
    final sameDateMeditations = widget.meditations
        .asMap()
        .entries
        .where((entry) => _formatDate(entry.value.createdAt) == dateStr)
        .toList();

    if (sameDateMeditations.length > 1) {
      // 같은 날짜가 여러 개면 순서 번호 추가
      final orderNumber = sameDateMeditations
          .indexWhere((entry) => entry.key == index) + 1;
      return '$dateStr 묵상($orderNumber)';
    } else {
      // 같은 날짜가 하나면 그냥 날짜만
      return '$dateStr 묵상';
    }
  }

  Widget _buildVerseItem(VerseReference verse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          verse.displayText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          verse.text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}