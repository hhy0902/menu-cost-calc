import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/cost_calculator.dart';
import '../providers/providers.dart';
import 'ingredient_edit_screen.dart';

class IngredientListScreen extends ConsumerWidget {
  const IngredientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingredientsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('식자재')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // IndexedStack에 FAB가 여러 개라 기본 태그가 겹친다
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const IngredientEditScreen())),
        icon: const Icon(Icons.add),
        label: const Text('재료 추가'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('등록된 식자재가 없습니다.'));
          }
          final byId = {for (final i in list) i.id: i};
          return ListView.separated(
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final g = list[index];
              final amount = '${amountText(g.purchaseAmount)}${g.unit.label}';
              final missing = CostCalculator.hasMissingIn(g, byId) ? ' · 재료 확인 필요' : '';
              return ListTile(
                title: Text(g.name),
                subtitle: Text(g.isPrepared
                    ? '직접 만듦 · 완성 $amount$missing'
                    : '$amount · ${won(g.purchasePrice)}'),
                trailing:
                    Text('${unitWon(CostCalculator.unitCostOf(g, byId))}/${g.unit.label}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => IngredientEditScreen(ingredient: g)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
