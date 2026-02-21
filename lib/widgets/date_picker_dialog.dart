/**
 * date_picker_dialog.dart
 * 
 * 날짜 선택 다이얼로그
 * 
 * 기능:
 * - 월(1-12) 선택 드롭다운
 * - 일(1-31) 선택 드롭다운
 * - 선택한 날짜를 콜백으로 반환
 * - 유효하지 않은 날짜 처리 (예: 2월 31일)
 */

import 'package:flutter/material.dart';

class DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;
  final Function(int year, int month)? onShow31Calendar;

  const DatePickerDialog({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
    this.onShow31Calendar,
  });

  @override
  State<DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<DatePickerDialog> {
  late FixedExtentScrollController _scrollController;
  late DateTime _selectedDate;
  final DateTime _today = DateTime.now();

  late List<DateTime> _dates;

  // 달력 보기용 31일 여부 - 1월, 3월만 정상 선택, 나머지는 달력 보기
  bool _is31st(DateTime date) {
    if (date.day != 31) return false;
    if (date.month == 1 || date.month == 3) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    // 날짜 리스트 생성 (31일 포함)
    _dates = _generateDates();

    final initialIndex = _dates.indexWhere((date) =>
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day);

    _scrollController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : (_dates.length ~/ 2),
    );
  }

  List<DateTime> _generateDates() {
    final List<DateTime> result = [];
    final start = _today.subtract(const Duration(days: 180));
    final end = _today.add(const Duration(days: 185));

    DateTime current = DateTime(start.year, start.month, start.day);
    while (!current.isAfter(end)) {
      result.add(current);
      // 30일 달에서 31일 삽입 (4월 이후만: 4, 6, 9, 11월)
      final daysInMonth = DateTime(current.year, current.month + 1, 0).day;
      if (current.day == 30 && daysInMonth == 30 && current.month >= 4) {
        result.add(DateTime(current.year, current.month, 31));
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    if (_is31st(date)) {
      return '${date.month}월 31일 (달력 보기)';
    }
    final isToday = date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;
    if (isToday) {
      return '${date.month}월 ${date.day}일 (Today)';
    }
    return '${date.month}월 ${date.day}일';
  }

  double _getTextSize(int offset) {
    switch (offset.abs()) {
      case 0:
        return 24.0; // 가운데 (선택된 날짜)
      case 1:
        return 18.0; // ±1일
      case 2:
        return 14.0; // ±2일
      default:
        return 12.0;
    }
  }

  Color _getTextColor(int offset, {bool is31st = false}) {
    if (is31st) return Colors.grey.shade400;
    switch (offset.abs()) {
      case 0:
        return Colors.black;
      case 1:
        return Colors.black87;
      case 2:
        return Colors.black54;
      default:
        return Colors.black38;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 300,
        height: 400,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '날짜 선택',
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
            const SizedBox(height: 20),

            // 날짜 휠 피커
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 선택 영역 표시
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                  ),

                  // 날짜 리스트
                  ListWheelScrollView.useDelegate(
                    controller: _scrollController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.5,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      final date = _dates[index];
                      if (!_is31st(date)) {
                        setState(() {
                          _selectedDate = date;
                        });
                      }
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: _dates.length,
                      builder: (context, index) {
                        final date = _dates[index];
                        final selectedIndex = _scrollController.selectedItem;
                        final offset = index - selectedIndex;

                        return GestureDetector(
                          onTap: () {
                            if (offset == 0) {
                              if (_is31st(date)) {
                                // 31일: 달력 표시
                                widget.onDateSelected(date);
                                Navigator.pop(context);
                              } else {
                                widget.onDateSelected(_selectedDate);
                                Navigator.pop(context);
                              }
                            } else {
                              _scrollController.animateToItem(
                                index,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Center(
                            child: Text(
                              _formatDate(date),
                              style: TextStyle(
                                fontSize: _getTextSize(offset),
                                color: _getTextColor(offset, is31st: _is31st(date)),
                                fontWeight: offset == 0 && !_is31st(date)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontStyle: _is31st(date) ? FontStyle.italic : FontStyle.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 확인 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onDateSelected(_selectedDate);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _is31st(_selectedDate) ? Colors.grey : Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '선택',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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