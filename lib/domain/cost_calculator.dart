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
  });

  final String name;
  final double amount;
  final String unitLabel;
  final double cost;
  final bool missing; // 재료가 삭제된 경우 true
}

class MenuCost {
  const MenuCost({required this.menu, required this.lines, required this.vatIncluded});

  final Menu menu;
  final List<CostLine> lines;
  final bool vatIncluded;

  /// 부가세를 뺀 실제 매출(공급가액). 부가세 미포함이면 판매가 그대로.
  double get netPrice =>
      vatIncluded ? menu.price / (1 + CostCalculator.vatRate) : menu.price.toDouble();
  double get vat => menu.price - netPrice;

  double get total => lines.fold<double>(0, (sum, l) => sum + l.cost);
  double get costRate => netPrice <= 0 ? 0 : total / netPrice;
  bool get hasMissing => lines.any((l) => l.missing);
}

class ChannelProfit {
  const ChannelProfit({
    required this.channel,
    required this.fee,
    required this.net,
    required this.netRate,
  });

  final SalesChannel channel;
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
        );
      }
      return CostLine(
        name: ing.name,
        amount: item.amount,
        unitLabel: ing.unit.label,
        cost: ing.unitCost * item.amount,
        missing: false,
      );
    }).toList();
    return MenuCost(menu: menu, lines: lines, vatIncluded: vatIncluded);
  }

  static ChannelProfit profit(MenuCost cost, SalesChannel channel) {
    // 수수료는 고객이 낸 금액(부가세 포함 판매가) 전체에 붙는다
    final fee = cost.menu.price * channel.feeRate;
    final net = cost.netPrice - fee - cost.total;
    return ChannelProfit(
      channel: channel,
      fee: fee,
      net: net,
      netRate: cost.netPrice <= 0 ? 0 : net / cost.netPrice,
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
