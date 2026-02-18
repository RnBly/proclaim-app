/// reading_calendar_dialog.dart
///
/// 읽기 현황 달력 다이얼로그
///
/// 기능:
/// - 월별 1일~말일 달력 표시
/// - 각 날짜 아래 읽기 진행률(%) 표시
/// - 날짜 탭하면 해당 날짜 본문으로 이동

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/preferences_service.dart';

class ReadingCalendarDialog extends StatefulWidget {
  final String userId;
  final DateTime currentDate;
  final Function(DateTime) onDateSelected;

  const ReadingCalendarDialog({
    super.key,
    required this.userId,
    required this.currentDate,
    required this.onDateSelected,
  });

  @override
  State<ReadingCalendarDialog> createState() => _ReadingCalendarDialogState();
}

class _ReadingCalendarDialogState extends State<ReadingCalendarDialog> {
  late int _viewYear;
  late int _viewMonth;
  Map<int, int> _progressMap = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _viewYear = widget.currentDate.year;
    _viewMonth = widget.currentDate.month;
    _loadProgress();
    // 3초마다 진행률 갱신 (실시간 반영)
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _loadProgress();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadProgress() {
    setState(() {
      _progressMap = PreferencesService().getMonthlyProgress(
        widget.userId,
        _viewYear,
        _viewMonth,
      );
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      final newDate = DateTime(_viewYear, _viewMonth + delta, 1);
      _viewYear = newDate.year;
      _viewMonth = newDate.month;
      _loadProgress();
    });
  }

  Color _progressColor(int percent) {
    if (percent == 100) return Colors.blue.shade700;
    if (percent >= 66) return Colors.blue.shade400;
    if (percent >= 33) return Colors.blue.shade200;
    if (percent > 0) return Colors.blue.shade100;
    return Colors.grey.shade100;
  }

  Color _textColor(int percent) {
    if (percent >= 66) return Colors.white;
    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_viewYear, _viewMonth + 1, 0).day;
    final today = DateTime.now();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '$_viewYear년 $_viewMonth월',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 달력 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.75,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final date = DateTime(_viewYear, _viewMonth, day);
                final percent = _progressMap[day] ?? 0;
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;
                final isSelected = date.year == widget.currentDate.year &&
                    date.month == widget.currentDate.month &&
                    date.day == widget.currentDate.day;

                return GestureDetector(
                  onTap: () {
                    widget.onDateSelected(date);
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _progressColor(percent),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Colors.blue.shade700
                            : isToday
                                ? Colors.orange
                                : Colors.transparent,
                        width: isSelected || isToday ? 2 : 0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _textColor(percent),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          percent > 0 ? '$percent%' : '',
                          style: TextStyle(
                            fontSize: 9,
                            color: _textColor(percent).withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // 범례
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(Colors.grey.shade100, '0%'),
                const SizedBox(width: 8),
                _buildLegend(Colors.blue.shade100, '1~32%'),
                const SizedBox(width: 8),
                _buildLegend(Colors.blue.shade200, '33~65%'),
                const SizedBox(width: 8),
                _buildLegend(Colors.blue.shade400, '66~99%'),
                const SizedBox(width: 8),
                _buildLegend(Colors.blue.shade700, '100%'),
              ],
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey)),
      ],
    );
  }
}