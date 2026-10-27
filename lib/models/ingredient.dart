import 'package:cloud_firestore/cloud_firestore.dart';

import 'unit_type.dart';

class Ingredient {
  const Ingredient({
    this.id = '',
    required this.name,
    required this.unit,
    required this.purchaseAmount,
    required this.purchasePrice,
  });

  final String id; // 빈 문자열이면 새 문서
  final String name;
  final UnitType unit;
  final double purchaseAmount; // 구매 단위량 (예: 1000ml)
  final int purchasePrice; // 구매가 (원)

  /// 단위(g, ml, 개)당 단가. 저장하지 않고 항상 계산한다.
  double get unitCost => purchaseAmount <= 0 ? 0 : purchasePrice / purchaseAmount;

  factory Ingredient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    return Ingredient(
      id: doc.id,
      name: d['name'] as String? ?? '',
      unit: UnitType.fromName(d['unit'] as String?),
      purchaseAmount: (d['purchaseAmount'] as num?)?.toDouble() ?? 0,
      purchasePrice: (d['purchasePrice'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit.name,
        'purchaseAmount': purchaseAmount,
        'purchasePrice': purchasePrice,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
