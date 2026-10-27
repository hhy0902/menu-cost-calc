import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/cost_calculator.dart';
import '../models/app_settings.dart';
import '../providers/providers.dart';
import 'menu_detail_screen.dart';
import 'menu_edit_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final costsAsync = ref.watch(menuCostsProvider);
    final warningRate =
        ref.watch(settingsProvider).asData?.value.warningRate ?? AppSettings.defaults.warningRate;

    return Scaffold(
      appBar: AppBar(title: const Text('메뉴 원가')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null, // IndexedStack에 FAB가 여러 개라 기본 태그가 겹친다
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MenuEditScreen())),
        icon: const Icon(Icons.add),
        label: const Text('메뉴 추가'),
      ),
      body: costsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (costs) {
          if (costs.isEmpty) {
            return const Center(
              child: Text(
                '등록된 메뉴가 없습니다.\n식자재를 먼저 등록한 뒤 메뉴를 추가하세요.',
                textAlign: TextAlign.center,
              ),
            );
          }
          // 원가율이 높은(위험한) 메뉴가 위로
          final sorted = [...costs]..sort((a, b) => b.costRate.compareTo(a.costRate));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: sorted.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _MenuCostCard(cost: sorted[index], warningRate: warningRate),
          );
        },
      ),
    );
  }
}

class _MenuCostCard extends StatelessWidget {
  const _MenuCostCard({required this.cost, required this.warningRate});

  final MenuCost cost;
  final double warningRate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = cost.costRate >= warningRate;
    final missing = cost.hasMissing ? ' · 재료 확인 필요' : '';

    return Card(
      child: ListTile(
        title: Text(cost.menu.name),
        subtitle: Text('판매가 ${won(cost.menu.price)} · 원가 ${won(cost.total)}$missing'),
        trailing: Text(
          percent(cost.costRate),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: over ? scheme.error : scheme.primary,
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MenuDetailScreen(menuId: cost.menu.id)),
        ),
      ),
    );
  }
}
