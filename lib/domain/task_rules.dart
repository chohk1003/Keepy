import 'package:characters/characters.dart';

/// 앞뒤 공백 제거 후 1~100자 (사람이 보는 글자 기준)[cite: 14]
bool isValidTitle(String raw) {
  final n = raw.trim().characters.length; // String.length는 이모지를 2로 세므로 characters 사용
  return n >= 1 && n <= 100;
}

/// 다이얼 +n일 계산 (DateTime 성분으로 계산하여 서머타임 오차 방지)[cite: 14]
DateTime dueAfter(DateTime base, int days) {
  return DateTime(base.year, base.month, base.day + days);
}