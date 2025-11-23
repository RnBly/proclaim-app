import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/meditation.dart';

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

  // 본문(구절) 복사 함수
  void _copyVerses() {
    // 구절 텍스트만 생성
    final versesText = _currentMeditation.verses
        .map((v) => '${v.displayText}\n${v.text}')
        .join('\n\n');

    Clipboard.setData(ClipboardData(text: versesText));

    // 복사 완료 스낵바
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('본문이 복사되었습니다'),
        duration: Duration(seconds: 2),
      ),
    );
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
                        Navigator.pop(context);
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