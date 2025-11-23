import 'package:flutter/material.dart';

class MeditationColors {
  // 파스텔 톤 하이라이트 색상
  static const Color yellow = Color(0xFFFFF9C4); // 파스텔 노란색
  static const Color blue = Color(0xFFBBDEFB); // 파스텔 파란색
  static const Color red = Color(0xFFFFCDD2); // 파스텔 붉은색
  static const Color green = Color(0xFFC8E6C9); // 파스텔 녹색
  static const Color orange = Color(0xFFFFE0B2); // 파스텔 주황색

  // 색상 이름과 Color 매핑
  static const Map<String, Color> colorMap = {
    'yellow': yellow,
    'blue': blue,
    'red': red,
    'green': green,
    'orange': orange,
  };

  // 색상 선택 옵션 (UI용)
  static const List<HighlightColorOption> options = [
    HighlightColorOption(name: 'yellow', color: yellow, displayName: '노란색'),
    HighlightColorOption(name: 'blue', color: blue, displayName: '파란색'),
    HighlightColorOption(name: 'red', color: red, displayName: '붉은색'),
    HighlightColorOption(name: 'green', color: green, displayName: '녹색'),
    HighlightColorOption(name: 'orange', color: orange, displayName: '주황색'),
  ];

  // 색상 이름으로 Color 가져오기
  static Color? getColor(String name) {
    return colorMap[name];
  }
}

class HighlightColorOption {
  final String name;
  final Color color;
  final String displayName;

  const HighlightColorOption({
    required this.name,
    required this.color,
    required this.displayName,
  });
}