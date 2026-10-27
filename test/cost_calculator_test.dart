import 'package:cost_test1/domain/cost_calculator.dart';
import 'package:cost_test1/models/app_settings.dart';
import 'package:cost_test1/models/ingredient.dart';
import 'package:cost_test1/models/menu.dart';
import 'package:cost_test1/models/unit_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 문서의 확인 예시: 우유 1000ml 2,800원, 원두 1000g 25,000원, 카페라떼 4,500원
  const milk = Ingredient(
      id: 'milk', name: '우유', unit: UnitType.ml, purchaseAmount: 1000, purchasePrice: 2800);
  const beans = Ingredient(
      id: 'beans', name: '원두', unit: UnitType.g, purchaseAmount: 1000, purchasePrice: 25000);
  const latte = Menu(id: 'latte', name: '카페라떼', price: 4500, recipe: [
    RecipeItem(ingredientId: 'milk', amount: 200),
    RecipeItem(ingredientId: 'beans', amount: 18),
  ]);
  final byId = {milk.id: milk, beans.id: beans};

  test('단위당 단가 = 구매가 ÷ 구매량', () {
    expect(milk.unitCost, closeTo(2.8, 1e-9));
  });

  test('메뉴 원가와 원가율', () {
    final cost = CostCalculator.calculate(latte, byId, vatIncluded: false);
    expect(cost.lines[0].cost, closeTo(560, 1e-9));
    expect(cost.total, closeTo(1010, 1e-9));
    expect(cost.costRate, closeTo(1010 / 4500, 1e-9));
    expect(cost.hasMissing, isFalse);
  });

  test('채널 순이익 = 판매가 × (1 - 수수료율) - 원가', () {
    final cost = CostCalculator.calculate(latte, byId, vatIncluded: false);
    final p = CostCalculator.profit(cost, const SalesChannel(name: '배달앱', feeRate: 0.1));
    expect(p.fee, closeTo(450, 1e-9));
    expect(p.net, closeTo(3040, 1e-9));
  });

  test('적정 판매가는 100원 단위 올림', () {
    expect(CostCalculator.suggestedPrice(1010, 0.30, vatIncluded: false), 3400);
    expect(CostCalculator.suggestedPrice(0, 0.30, vatIncluded: false), 0);
  });

  test('삭제된 재료는 원가 0원, 재료 확인 필요', () {
    final cost = CostCalculator.calculate(latte, {milk.id: milk}, vatIncluded: false);
    expect(cost.hasMissing, isTrue);
    expect(cost.lines[1].name, '삭제된 재료');
    expect(cost.total, closeTo(560, 1e-9));
  });

  group('부가세 포함 판매가', () {
    final cost = CostCalculator.calculate(latte, byId, vatIncluded: true);

    test('원가율은 공급가액(판매가 ÷ 1.1) 기준', () {
      expect(cost.netPrice, closeTo(4500 / 1.1, 1e-9));
      expect(cost.vat, closeTo(4500 - 4500 / 1.1, 1e-9));
      expect(cost.costRate, closeTo(1010 / (4500 / 1.1), 1e-9));
    });

    test('수수료는 판매가 전체에, 순이익은 공급가액에서', () {
      final p = CostCalculator.profit(cost, const SalesChannel(name: '배달앱', feeRate: 0.1));
      expect(p.fee, closeTo(450, 1e-9));
      expect(p.net, closeTo(4500 / 1.1 - 450 - 1010, 1e-9));
    });

    test('적정 판매가에 부가세를 더해 올림', () {
      expect(CostCalculator.suggestedPrice(1010, 0.30, vatIncluded: true), 3800);
    });
  });

  test('적정 판매가가 딱 맞아떨어지면 한 단계 더 올리지 않음', () {
    // 900 / 0.3 * 1.1 = 3300.0000000000005
    expect(CostCalculator.suggestedPrice(900, 0.30, vatIncluded: true), 3300);
    expect(CostCalculator.suggestedPrice(900, 0.30, vatIncluded: false), 3000);
  });
}
