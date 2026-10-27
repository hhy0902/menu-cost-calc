import 'package:intl/intl.dart';

final _wonFormat = NumberFormat('#,##0');

/// 4500 -> "4,500원"
String won(num value) => '${_wonFormat.format(value.round())}원';

/// 단위당 단가처럼 소수가 필요한 금액: 2.8 -> "2.80원"
String unitWon(double value) => '${value.toStringAsFixed(2)}원';

/// 0.345 -> "34.5%"
String percent(double rate) => '${(rate * 100).toStringAsFixed(1)}%';

/// 200.0 -> "200", 12.5 -> "12.5"
String amountText(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

/// 입력칸에 보여줄 퍼센트 값: 0.068 -> "6.8"
String rateInput(double rate) => amountText(rate * 100);
