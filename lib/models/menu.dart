import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeItem {
  const RecipeItem({required this.ingredientId, required this.amount});

  final String ingredientId;
  final double amount; // 재료 단위 기준 사용량

  factory RecipeItem.fromMap(Map<String, dynamic> m) => RecipeItem(
        ingredientId: m['ingredientId'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'ingredientId': ingredientId, 'amount': amount};
}

class Menu {
  const Menu({
    this.id = '',
    required this.name,
    required this.price,
    this.recipe = const [],
  });

  final String id;
  final String name;
  final int price; // 판매가 (원)
  final List<RecipeItem> recipe;

  factory Menu.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final raw = d['recipe'] as List<dynamic>? ?? const [];
    return Menu(
      id: doc.id,
      name: d['name'] as String? ?? '',
      price: (d['price'] as num?)?.toInt() ?? 0,
      recipe: raw
          .map((e) => RecipeItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'recipe': recipe.map((r) => r.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
