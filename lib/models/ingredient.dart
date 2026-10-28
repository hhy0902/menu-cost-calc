import 'package:cloud_firestore/cloud_firestore.dart';

import 'menu.dart';
import 'unit_type.dart';

class Ingredient {
  const Ingredient({
    this.id = '',
    required this.name,
    required this.unit,
    required this.purchaseAmount,
    required this.purchasePrice,
    this.recipe = const [],
  });

  final String id; // 빈 문자열이면 새 문서
  final String name;
  final UnitType unit;
  final double purchaseAmount; // 구매 단위량 (예: 1000ml). 반제품이면 완성량
  final int purchasePrice; // 구매가 (원). 반제품이면 쓰지 않음
  final List<RecipeItem> recipe; // 비어 있지 않으면 직접 만드는 재료(반제품). 일반 재료만 들어간다

  bool get isPrepared => recipe.isNotEmpty;

  /// 사 온 재료의 단위(g, ml, 개)당 단가. 저장하지 않고 항상 계산한다.
  /// 반제품 단가는 다른 재료값이 필요해서 CostCalculator.unitCostOf로 구한다.
  double get unitCost => purchaseAmount <= 0 ? 0 : purchasePrice / purchaseAmount;

  factory Ingredient.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final raw = d['recipe'] as List<dynamic>? ?? const [];
    return Ingredient(
      id: doc.id,
      name: d['name'] as String? ?? '',
      unit: UnitType.fromName(d['unit'] as String?),
      purchaseAmount: (d['purchaseAmount'] as num?)?.toDouble() ?? 0,
      purchasePrice: (d['purchasePrice'] as num?)?.toInt() ?? 0,
      recipe: raw
          .map((e) => RecipeItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'unit': unit.name,
        'purchaseAmount': purchaseAmount,
        'purchasePrice': purchasePrice,
        'recipe': recipe.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
