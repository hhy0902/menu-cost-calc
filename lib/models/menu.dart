import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeItem {
  const RecipeItem({
    required this.ingredientId,
    required this.amount,
    this.channelIds = const [],
  });

  final String ingredientId;
  final double amount; // 재료 단위 기준 사용량
  final List<String> channelIds; // 비어 있으면 모든 채널, 아니면 이 채널에만 (컵·포장 같은 부자재)

  factory RecipeItem.fromMap(Map<String, dynamic> m) => RecipeItem(
        ingredientId: m['ingredientId'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        channelIds: [for (final c in m['channelIds'] as List<dynamic>? ?? const []) c as String],
      );

  Map<String, dynamic> toMap() =>
      {'ingredientId': ingredientId, 'amount': amount, 'channelIds': channelIds};
}

class Menu {
  const Menu({
    this.id = '',
    required this.name,
    required this.price,
    this.recipe = const [],
    this.channelPrices = const {},
  });

  final String id;
  final String name;
  final int price; // 기본 판매가 (원)
  final List<RecipeItem> recipe;
  final Map<String, int> channelPrices; // 채널 id -> 판매가. 없으면 기본 판매가

  int priceFor(String channelId) => channelPrices[channelId] ?? price;

  factory Menu.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final raw = d['recipe'] as List<dynamic>? ?? const [];
    final prices = Map<String, dynamic>.from(d['channelPrices'] as Map? ?? const {});
    return Menu(
      id: doc.id,
      name: d['name'] as String? ?? '',
      price: (d['price'] as num?)?.toInt() ?? 0,
      recipe: raw
          .map((e) => RecipeItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      channelPrices: {for (final e in prices.entries) e.key: (e.value as num).toInt()},
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'recipe': recipe.map((r) => r.toMap()).toList(),
        'channelPrices': channelPrices,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
