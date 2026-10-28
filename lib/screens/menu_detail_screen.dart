import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/cost_calculator.dart';
import '../models/app_settings.dart';
import '../models/menu.dart';
import '../providers/providers.dart';
import 'menu_edit_screen.dart';

class MenuDetailScreen extends ConsumerWidget {
  const MenuDetailScreen({super.key, required this.menuId});

  final String menuId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cost = ref.watch(menuCostProvider(menuId));
    final settings = ref.watch(settingsProvider).asData?.value ?? AppSettings.defaults;
    final theme = Theme.of(context);

    if (cost == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final over = cost.costRate >= settings.warningRate;
    final hasOrphan = cost.hasOrphanLines({for (final c in settings.channels) c.id});
    final suggested = CostCalculator.suggestedPrice(cost.total, settings.targetRate,
        vatIncluded: cost.vatIncluded);

    return Scaffold(
      appBar: AppBar(
        title: Text(cost.menu.name),
        actions: [
          IconButton(
            tooltip: '복제',
            icon: const Icon(Icons.copy_outlined),
            // id 없이 넘기면 새 메뉴로 저장된다
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MenuEditScreen(
                menu: Menu(
                  name: '${cost.menu.name} (복사)',
                  price: cost.menu.price,
                  recipe: cost.menu.recipe,
                  channelPrices: cost.menu.channelPrices,
                ),
              ),
            )),
          ),
          IconButton(
            tooltip: '수정',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => MenuEditScreen(menu: cost.menu)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _Stat(label: '판매가', value: won(cost.menu.price)),
              _Stat(label: '원가', value: won(cost.total)),
              _Stat(
                label: '원가율',
                value: percent(cost.costRate),
                color: over ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ],
          ),
          if (cost.vatIncluded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '원가율·순이익은 부가세 ${won(cost.vat)}을 뺀 공급가액 ${won(cost.netPrice)} 기준',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (cost.hasMissing)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('삭제된 재료가 있습니다. 메뉴 레시피나 반제품 레시피를 수정하세요.'),
              ),
            ),
          if (hasOrphan)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('삭제된 채널에만 적용된 부자재가 있어 계산에서 빠졌습니다. 레시피를 수정하세요.'),
              ),
            ),
          const SizedBox(height: 24),
          Text('재료별 원가', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          // 채널 전용 부자재는 아래 채널별 순이익에 합쳐 보여준다
          for (final line in cost.lines)
            if (line.channelIds.isEmpty) _CostLineTile(line: line, total: cost.total),
          const SizedBox(height: 24),
          Text('채널별 순이익', style: theme.textTheme.titleMedium),
          for (final ch in settings.channels)
            _ChannelTile(profit: CostCalculator.profit(cost, ch)),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: Text('목표 원가율 ${percent(settings.targetRate)} 기준 적정 판매가'),
              subtitle: Text('현재 판매가 ${won(cost.menu.price)}'),
              trailing: Text(
                suggested == 0 ? '-' : won(suggested), // 레시피가 없으면 계산할 수 없다
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: text.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CostLineTile extends StatelessWidget {
  const _CostLineTile({required this.line, required this.total});

  final CostLine line;
  final double total;

  @override
  Widget build(BuildContext context) {
    final share = total <= 0 ? 0.0 : line.cost / total;
    // 삭제된 재료는 단위가 없다. 단위가 있는데 missing이면 반제품 속 재료가 삭제된 경우
    final label = line.unitLabel.isEmpty
        ? line.name
        : '${line.name} ${amountText(line.amount)}${line.unitLabel}'
            '${line.missing ? ' · 반제품 재료 확인' : ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: line.missing
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
              Text('${won(line.cost)} (${percent(share)})'),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: share,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({required this.profit});

  final ChannelProfit profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(profit.channel.name),
      subtitle: Text([
        '판매가 ${won(profit.price)}',
        '수수료 ${percent(profit.channel.feeRate)} · ${won(profit.fee)}',
        if (profit.extraCost > 0) '부자재 ${won(profit.extraCost)}',
      ].join('\n')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            won(profit.net),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: profit.net < 0 ? theme.colorScheme.error : null,
            ),
          ),
          Text('순이익률 ${percent(profit.netRate)}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
