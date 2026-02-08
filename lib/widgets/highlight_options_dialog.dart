/**
 * highlight_options_dialog.dart
 * 
 * 하이라이트된 구절 클릭 시 표시되는 옵션 다이얼로그
 * 
 * 옵션:
 * - 색상 변경
 * - 묵상 작성하기 (하이라이트를 묵상으로 전환)
 * - 삭제
 */

import 'package:flutter/material.dart';
import '../models/meditation.dart';

enum HighlightOption {
  changeColor,
  addMeditation,
  delete,
}

class HighlightOptionsDialog extends StatelessWidget {
  final Meditation highlight;
  final Function(HighlightOption) onOptionSelected;

  const HighlightOptionsDialog({
    super.key,
    required this.highlight,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
            // 제목
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getColor(highlight.highlightColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  '하이라이트 옵션',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // 구절 정보
            Text(
              _getVerseInfo(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 색상 변경 버튼
            _buildOptionButton(
              context,
              icon: Icons.palette,
              label: '색상 변경',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                onOptionSelected(HighlightOption.changeColor);
              },
            ),
            
            const SizedBox(height: 12),
            
            // 묵상 작성하기 버튼
            _buildOptionButton(
              context,
              icon: Icons.edit_note,
              label: '묵상 작성하기',
              color: const Color(0xFFCE6E26),
              onTap: () {
                Navigator.pop(context);
                onOptionSelected(HighlightOption.addMeditation);
              },
            ),
            
            const SizedBox(height: 12),
            
            // 삭제 버튼
            _buildOptionButton(
              context,
              icon: Icons.delete_outline,
              label: '삭제',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                onOptionSelected(HighlightOption.delete);
              },
            ),
            
            const SizedBox(height: 16),
            
            // 닫기 버튼
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getVerseInfo() {
    if (highlight.verses.isEmpty) return '';
    
    final verses = highlight.verses;
    if (verses.length == 1) {
      final v = verses.first;
      return '${v.book} ${v.chapter}:${v.verse}';
    } else {
      final first = verses.first;
      final last = verses.last;
      return '${first.book} ${first.chapter}:${first.verse}-${last.verse}';
    }
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'yellow':
        return Colors.yellow[700]!;
      case 'green':
        return Colors.green[400]!;
      case 'blue':
        return Colors.blue[400]!;
      case 'purple':
        return Colors.purple[300]!;
      case 'pink':
        return Colors.pink[300]!;
      default:
        return Colors.grey[400]!;
    }
  }
}