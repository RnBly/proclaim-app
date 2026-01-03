/**
 * meditation_colors.dart
 * 
 * 묵상 기능에서 사용되는 하이라이트 색상 정의
 * 
 * 역할:
 * - 성경 구절 하이라이트에 사용할 파스텔 톤 색상 제공
 * - 색상 이름과 실제 Color 객체 매핑
 * - UI에서 색상 선택 시 사용할 옵션 리스트 제공
 * 
 * 사용 위치:
 * - color_selection_dialog.dart: 색상 선택 다이얼로그
 * - meditation_writing_dialog.dart: 묵상 작성 시 하이라이트
 * - meditation_view_dialog.dart: 저장된 묵상 보기
 */

import 'package:flutter/material.dart';

/**
 * MeditationColors 클래스
 * 
 * 묵상 하이라이트에 사용되는 색상을 관리하는 클래스
 * 모든 멤버는 static으로 선언되어 인스턴스 생성 없이 사용 가능
 */
class MeditationColors {
  // ========== 파스텔 톤 하이라이트 색상 정의 ==========
  // 부드러운 파스텔 톤을 사용하여 텍스트 가독성 유지
  
  /// 파스텔 노란색 - 일반적인 강조에 사용
  static const Color yellow = Color(0xFFFFF9C4);
  
  /// 파스텔 파란색 - 중요한 약속이나 진리에 사용
  static const Color blue = Color(0xFFBBDEFB);
  
  /// 파스텔 붉은색 - 경고나 특별히 주의할 내용에 사용
  static const Color red = Color(0xFFFFCDD2);
  
  /// 파스텔 녹색 - 소망이나 위로의 말씀에 사용
  static const Color green = Color(0xFFC8E6C9);
  
  /// 파스텔 주황색 - 감사나 기쁨의 내용에 사용
  static const Color orange = Color(0xFFFFE0B2);

  // ========== 색상 이름 ↔ Color 객체 매핑 ==========
  /**
   * colorMap
   * 
   * 문자열 색상 이름을 실제 Color 객체로 변환하기 위한 Map
   * Firestore에 저장된 색상 이름('yellow', 'blue' 등)을
   * 실제 Color로 변환할 때 사용
   * 
   * 사용 예:
   * Color? highlightColor = MeditationColors.colorMap['yellow'];
   */
  static const Map<String, Color> colorMap = {
    'yellow': yellow,
    'blue': blue,
    'red': red,
    'green': green,
    'orange': orange,
  };

  // ========== UI용 색상 선택 옵션 ==========
  /**
   * options
   * 
   * 색상 선택 UI에 표시할 옵션 리스트
   * 각 옵션은 내부 이름, 색상, 화면 표시 이름을 포함
   * 
   * 사용 위치:
   * - ColorSelectionDialog: 색상 선택 버튼 그리드 생성
   */
  static const List<HighlightColorOption> options = [
    HighlightColorOption(name: 'yellow', color: yellow, displayName: '노란색'),
    HighlightColorOption(name: 'blue', color: blue, displayName: '파란색'),
    HighlightColorOption(name: 'red', color: red, displayName: '붉은색'),
    HighlightColorOption(name: 'green', color: green, displayName: '녹색'),
    HighlightColorOption(name: 'orange', color: orange, displayName: '주황색'),
  ];

  // ========== 유틸리티 메서드 ==========
  /**
   * 색상 이름으로 Color 객체 가져오기
   * 
   * @param name 색상 이름 ('yellow', 'blue', 'red', 'green', 'orange')
   * @return Color 객체, 없으면 null
   * 
   * 사용 예:
   * ```dart
   * Color? color = MeditationColors.getColor('yellow');
   * if (color != null) {
   *   // 색상 사용
   * }
   * ```
   */
  static Color? getColor(String name) {
    return colorMap[name];
  }
}

/**
 * HighlightColorOption 클래스
 * 
 * 색상 선택 옵션을 표현하는 데이터 클래스
 * 
 * 속성:
 * - name: 내부적으로 사용되는 색상 이름 (Firestore 저장 시 사용)
 * - color: 실제 Color 객체
 * - displayName: UI에 표시될 한글 이름
 */
class HighlightColorOption {
  /// 내부 식별용 색상 이름 (예: 'yellow', 'blue')
  final String name;
  
  /// 실제 Color 객체
  final Color color;
  
  /// UI에 표시될 한글 이름 (예: '노란색', '파란색')
  final String displayName;

  /**
   * HighlightColorOption 생성자
   * 
   * @param name 내부 색상 이름
   * @param color 실제 Color 객체
   * @param displayName UI 표시 이름
   */
  const HighlightColorOption({
    required this.name,
    required this.color,
    required this.displayName,
  });
}
