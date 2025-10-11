import 'package:flutter/material.dart';

enum Translation {
  korean,  // 개역개정
  esv,     // ESV
  compare  // 역본대조
}

class TranslationDialog extends StatelessWidget {
  final Translation currentTranslation;
  final Function(Translation) onTranslationChanged;

  const TranslationDialog({
    super.key,
    required this.currentTranslation,
    required this.onTranslationChanged,
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
              '번역 선택',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildTranslationOption(
              context,
              '개역개정',
              Translation.korean,
            ),
            const SizedBox(height: 12),
            _buildTranslationOption(
              context,
              'ESV',
              Translation.esv,
            ),
            const SizedBox(height: 12),
            _buildTranslationOption(
              context,
              '역본대조',
              Translation.compare,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationOption(
      BuildContext context,
      String label,
      Translation translation,
      ) {
    final isSelected = currentTranslation == translation;

    return GestureDetector(
      onTap: () {
        onTranslationChanged(translation);
        Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.blue : Colors.black54,
          ),
        ),
      ),
    );
  }
}