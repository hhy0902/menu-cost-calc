import '../models/app_settings.dart';
import '../models/ingredient.dart';
import '../models/menu.dart';

/// 레시피 한 줄의 계산 결과
class CostLine {
  const CostLine({
    required this.name,
    required this.amount,
    required this.unitLabel,
    required this.cost,
    required this.missing,
    required this.channelIds,
  });

  final String name;
  final double amount;
  final String unitLabel;
  final double cost;
  final bool missing; // 재료가 삭제된 경우 true
  final List<String> channelIds; // 비어 있으면 모든 채널 공통

  bool appliesTo(String channelId) => channelIds.isEmpty || channelIds.contains(channelId);
}

class MenuCost {
  const MenuCost({required this.menu, required this.lines, required this.vatIncluded});

  final Menu menu;
  final List<CostLine> lines;
  final bool vatIncluded;

  /// 부가세를 뺀 실제 매출(공급가액). 부가세 미포함이면 판매가 그대로.
  double netOf(int price) =>
      vatIncluded ? price / (1 + CostCalculator.vatRate) : price.toDouble();
  double get netPrice => netOf(menu.price);
  double get vat => menu.price - netPrice;

  /// 모든 채널 공통 원가. 대시보드 원가율과 적정 판매가는 이 값 기준.
  double get total => _sum((l) => l.channelIds.isEmpty);

  /// 공통 원가 + 이 채널에만 드는 부자재
  double costFor(String channelId) => _sum((l) => l.appliesTo(channelId));

  double get costRate => netPrice <= 0 ? 0 : total / netPrice;
  bool get hasMissing => lines.any((l) => l.missing);

  double _sum(bool Function(CostLine) test) =>
      lines.where(test).fold<double>(0, (sum, l) => sum + l.cost);
}

class ChannelProfit {
  const ChannelProfit({
    required this.channel,
    required this.price,
    required this.extraCost,
    required this.fee,
    required this.net,
    required this.netRate,
  });

  final SalesChannel channel;
  final int price; // 이 채널 판매가
  final double extraCost; // 이 채널에만 드는 부자재 원가
  final double fee; // 수수료 금액
  final double net; // 순이익
  final double netRate; // 순이익률
}

class CostCalculator {
  const CostCalculator._();

  static const vatRate = 0.1;

  static MenuCost calculate(
    Menu menu,
    Map<String, Ingredient> ingredients, {
    required bool vatIncluded,
  }) {
    final lines = menu.recipe.map((item) {
      final ing = ingredients[item.ingredientId];
      if (ing == null) {
        return CostLine(
          name: '삭제된 재료',
          amount: item.amount,
          unitLabel: '',
          cost: 0,
          missing: true,
          channelIds: item.channelIds,
        );
      }
      return CostLine(
        name: ing.name,
        amount: item.amount,
        unitLabel: ing.unit.label,
        cost: ing.unitCost * item.amount,
        missing: false,
        channelIds: item.channelIds,
      );
    }).toList();
    return MenuCost(menu: menu, lines: lines, vatIncluded: vatIncluded);
  }

  static ChannelProfit profit(MenuCost cost, SalesChannel channel) {
    final price = cost.menu.priceFor(channel.id);
    final netPrice = cost.netOf(price);
    // 수수료는 고객이 낸 금액(부가세 포함 판매가) 전체에 붙는다
    final fee = price * channel.feeRate;
    final channelCost = cost.costFor(channel.id);
    final net = netPrice - fee - channelCost;
    return ChannelProfit(
      channel: channel,
      price: price,
      extraCost: channelCost - cost.total,
      fee: fee,
      net: net,
      netRate: netPrice <= 0 ? 0 : net / netPrice,
    );
  }

  /// 목표 원가율을 맞추는 판매가(부가세 포함 여부 반영), roundTo 단위로 올림
  static int suggestedPrice(
    double cost,
    double targetRate, {
    required bool vatIncluded,
    int roundTo = 100,
  }) {
    if (targetRate <= 0 || cost <= 0) return 0;
    final price = cost / targetRate * (vatIncluded ? 1 + vatRate : 1);
    // 1100.0000000002 같은 소수점 오차가 한 단계 위로 올림되지 않게
    return (price / roundTo - 1e-9).ceil() * roundTo;
  }
}
