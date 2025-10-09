import 'package:flutter/material.dart';

class DatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const DatePickerDialog({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<DatePickerDialog> {
  late FixedExtentScrollController _scrollController;
  late DateTime _selectedDate;
  final DateTime _today = DateTime.now();

  // 1년치 날짜 생성 (오늘 기준 -180일 ~ +180일)
  late List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;

    // 날짜 리스트 생성
    _dates = List.generate(365, (index) {
      return _today.subtract(Duration(days: 180 - index));
    });

    // 초기 선택 날짜의 인덱스 찾기
    final initialIndex = _dates.indexWhere((date) =>
    date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day);

    _scrollController = FixedExtentScrollController(
      initialItem: initialIndex >= 0 ? initialIndex : 180,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
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

  Color _getTextColor(int offset) {
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
                      setState(() {
                        _selectedDate = _dates[index];
                      });
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
                              // 가운데 날짜 클릭 시 선택하고 닫기
                              widget.onDateSelected(_selectedDate);
                              Navigator.pop(context);
                            } else {
                              // 다른 날짜 클릭 시 해당 날짜로 스크롤
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
                                color: _getTextColor(offset),
                                fontWeight: offset == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
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
                  backgroundColor: Colors.blue,
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