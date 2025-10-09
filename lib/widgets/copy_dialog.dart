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
        Navigator.pop(context);
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