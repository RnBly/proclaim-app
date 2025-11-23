import 'package:flutter/material.dart';
import '../models/meditation.dart';

// 묵상 절 선택 다이얼로그
class VerseSelectionDialog extends StatefulWidget {
  final List<VerseReference> availableVerses; // 현재 선택되어 있는 구절들

  const VerseSelectionDialog({
    super.key,
    required this.availableVerses,
  });

  @override
  State<VerseSelectionDialog> createState() => _VerseSelectionDialogState();
}

class _VerseSelectionDialogState extends State<VerseSelectionDialog> {
  final Set<int> _selectedIndices = {};
  bool _allSelected = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 헤더
            Row(
              children: [
                // 전체 선택 체크박스
                Checkbox(
                  value: _allSelected,
                  onChanged: (value) {
                    setState(() {
                      _allSelected = value ?? false;
                      if (_allSelected) {
                        _selectedIndices.addAll(
                          List.generate(widget.availableVerses.length, (i) => i),
                        );
                      } else {
                        _selectedIndices.clear();
                      }
                    });
                  },
                ),
                const SizedBox(width: 8),
                // 제목
                const Expanded(
                  child: Text(
                    '묵상 절 선택',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // X 버튼
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),

            // 구절 리스트
            Expanded(
              child: widget.availableVerses.isEmpty
                  ? const Center(
                child: Text(
                  '선택된 구절이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: widget.availableVerses.length,
                itemBuilder: (context, index) {
                  final verse = widget.availableVerses[index];
                  final isSelected = _selectedIndices.contains(index);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIndices.add(index);
                        } else {
                          _selectedIndices.remove(index);
                        }
                        _allSelected = _selectedIndices.length ==
                            widget.availableVerses.length;
                      });
                    },
                    title: Text(
                      verse.displayText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      verse.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 기록하기 버튼
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedIndices.isEmpty
                    ? null
                    : () {
                  final selectedVerses = _selectedIndices
                      .map((i) => widget.availableVerses[i])
                      .toList();
                  Navigator.pop(context, selectedVerses);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCE6E26),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '기록하기 (${_selectedIndices.length}개 선택)',
                  style: const TextStyle(
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
    );
  }
}