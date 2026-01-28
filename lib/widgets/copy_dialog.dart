/**
 * copy_dialog.dart
 * 
 * 선택된 성경 구절을 클립보드에 복사하는 다이얼로그
 * 
 * 기능:
 * - 선택된 구절을 포맷팅하여 표시
 * - "복사하기" 버튼 클릭 시 클립보드에 복사
 * - 복사 완료 시 스낵바로 알림
 */

import 'package:flutter/material.dart';

enum CopyFormat {
  korean,
  esv,
  compare
}

class CopyDialog extends StatelessWidget {
  final Function(CopyFormat) onFormatSelected;

  const CopyDialog({
    super.key,
    required this.onFormatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '복사 형식 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildFormatOption(context, '개역개정', CopyFormat.korean),
            const SizedBox(height: 12),
            _buildFormatOption(context, 'ESV', CopyFormat.esv),
            const SizedBox(height: 12),
            _buildFormatOption(context, '역본대조', CopyFormat.compare),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(BuildContext context, String label, CopyFormat format) {
    return GestureDetector(
      onTap: () {
        print('🟡 CopyDialog 옵션 선택됨: $label ($format)');
        // onFormatSelected만 호출 (Navigator.pop은 호출하는 쪽에서 처리)
        onFormatSelected(format);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}