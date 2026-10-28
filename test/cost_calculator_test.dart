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
  const store = SalesChannel(id: 'store', name: '매장', feeRate: 0);
  const delivery = SalesChannel(id: 'delivery', name: '배달앱', feeRate: 0.1);

  test('단위당 단가 = 구매가 ÷ 구매량', () {
    expect(milk.unitCost, closeTo(2.8, 1e-9));
  });

  test('수율이 있으면 단위당 단가 = 구매가 ÷ 구매량 ÷ 수율', () {
    // 양파 1000g 3,000원, 손질 후 90% -> 손질된 양파 1g당 3.33원
    const onion = Ingredient(
        id: 'onion',
        name: '양파',
        unit: UnitType.g,
        purchaseAmount: 1000,
        purchasePrice: 3000,
        yieldRate: 0.9);
    expect(onion.unitCost, closeTo(3000 / 1000 / 0.9, 1e-9));
    const menu = Menu(id: 'm', name: '볶음', price: 8000, recipe: [
      RecipeItem(ingredientId: 'onion', amount: 90),
    ]);
    final cost = CostCalculator.calculate(menu, {onion.id: onion}, vatIncluded: false);
    expect(cost.total, closeTo(300, 1e-9)); // 손질된 90g = 사 온 양파 100g 값
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
    final p = CostCalculator.profit(cost, delivery);
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
      final p = CostCalculator.profit(cost, delivery);
      expect(p.fee, closeTo(450, 1e-9));
      expect(p.net, closeTo(4500 / 1.1 - 450 - 1010, 1e-9));
    });

    test('적정 판매가에 부가세를 더해 올림', () {
      expect(CostCalculator.suggestedPrice(1010, 0.30, vatIncluded: true), 3800);
    });
  });

  group('채널별 판매가와 부자재', () {
    // 일회용 컵 100개 10,000원 -> 개당 100원, 배달에만 들어감
    const cup = Ingredient(
        id: 'cup', name: '컵', unit: UnitType.ea, purchaseAmount: 100, purchasePrice: 10000);
    const deliveryLatte = Menu(
      id: 'latte',
      name: '카페라떼',
      price: 4500,
      channelPrices: {'delivery': 5000},
      recipe: [
        RecipeItem(ingredientId: 'milk', amount: 200),
        RecipeItem(ingredientId: 'beans', amount: 18),
        RecipeItem(ingredientId: 'cup', amount: 1, channelIds: ['delivery']),
      ],
    );
    final cost = CostCalculator.calculate(
        deliveryLatte, {...byId, cup.id: cup}, vatIncluded: false);

    test('공통 원가와 원가율에는 채널 전용 부자재가 빠진다', () {
      expect(cost.total, closeTo(1010, 1e-9));
      expect(cost.costRate, closeTo(1010 / 4500, 1e-9));
      expect(cost.costFor('delivery'), closeTo(1110, 1e-9));
      expect(cost.costFor('store'), closeTo(1010, 1e-9));
    });

    test('채널 판매가가 없으면 기본 판매가, 부자재 없음', () {
      final p = CostCalculator.profit(cost, store);
      expect(p.price, 4500);
      expect(p.extraCost, closeTo(0, 1e-9));
      expect(p.net, closeTo(4500 - 1010, 1e-9));
    });

    test('채널 판매가로 수수료·순이익, 부자재 차감', () {
      final p = CostCalculator.profit(cost, delivery);
      expect(p.price, 5000);
      expect(p.fee, closeTo(500, 1e-9));
      expect(p.extraCost, closeTo(100, 1e-9));
      expect(p.net, closeTo(5000 - 500 - 1110, 1e-9));
    });

    test('부가세 포함이면 채널 판매가도 ÷ 1.1', () {
      final vatCost = CostCalculator.calculate(
          deliveryLatte, {...byId, cup.id: cup}, vatIncluded: true);
      final p = CostCalculator.profit(vatCost, delivery);
      expect(p.net, closeTo(5000 / 1.1 - 500 - 1110, 1e-9));
    });
  });

  group('반제품', () {
    // 설탕 1000g 2,000원(2원/g), 청포도 1000g 10,000원(10원/g)
    const sugar = Ingredient(
        id: 'sugar', name: '설탕', unit: UnitType.g, purchaseAmount: 1000, purchasePrice: 2000);
    const grape = Ingredient(
        id: 'grape', name: '청포도', unit: UnitType.g, purchaseAmount: 1000, purchasePrice: 10000);
    // 설탕 500g(1,000원) + 청포도 1000g(10,000원) -> 시럽 1200ml
    const syrup = Ingredient(
      id: 'syrup',
      name: '청포도 시럽',
      unit: UnitType.ml,
      purchaseAmount: 1200,
      purchasePrice: 0,
      recipe: [
        RecipeItem(ingredientId: 'sugar', amount: 500),
        RecipeItem(ingredientId: 'grape', amount: 1000),
      ],
    );
    const ade = Menu(id: 'ade', name: '청포도 에이드', price: 5000, recipe: [
      RecipeItem(ingredientId: 'syrup', amount: 40),
    ]);
    final all = {sugar.id: sugar, grape.id: grape, syrup.id: syrup};

    test('단위당 단가 = 레시피 재료비 ÷ 완성량', () {
      expect(syrup.isPrepared, isTrue);
      expect(CostCalculator.unitCostOf(syrup, all), closeTo(11000 / 1200, 1e-9));
      expect(CostCalculator.unitCostOf(sugar, all), closeTo(2, 1e-9));
    });

    test('메뉴 원가에 반제품 단가가 들어간다', () {
      final cost = CostCalculator.calculate(ade, all, vatIncluded: false);
      expect(cost.total, closeTo(40 * 11000 / 1200, 1e-9));
      expect(cost.hasMissing, isFalse);
    });

    test('재료값이 바뀌면 반제품을 쓰는 메뉴 원가도 바뀐다', () {
      const pricier = Ingredient(
          id: 'sugar', name: '설탕', unit: UnitType.g, purchaseAmount: 1000, purchasePrice: 4000);
      final cost = CostCalculator.calculate(ade, {...all, 'sugar': pricier}, vatIncluded: false);
      expect(cost.total, closeTo(40 * 12000 / 1200, 1e-9));
    });

    test('반제품 속 재료가 삭제되면 그만큼 빠지고 재료 확인 필요', () {
      final cost =
          CostCalculator.calculate(ade, {sugar.id: sugar, syrup.id: syrup}, vatIncluded: false);
      expect(cost.total, closeTo(40 * 1000 / 1200, 1e-9));
      expect(cost.hasMissing, isTrue);
    });

    test('반제품 안의 반제품은 계산하지 않고 재료 확인 필요', () {
      const base = Ingredient(
        id: 'base',
        name: '에이드 베이스',
        unit: UnitType.ml,
        purchaseAmount: 100,
        purchasePrice: 0,
        recipe: [RecipeItem(ingredientId: 'syrup', amount: 100)],
      );
      final withBase = {...all, base.id: base};
      expect(CostCalculator.unitCostOf(base, withBase), 0);
      expect(CostCalculator.hasMissingIn(base, withBase), isTrue);
    });
  });

  test('적정 판매가가 딱 맞아떨어지면 한 단계 더 올리지 않음', () {
    // 900 / 0.3 * 1.1 = 3300.0000000000005
    expect(CostCalculator.suggestedPrice(900, 0.30, vatIncluded: true), 3300);
    expect(CostCalculator.suggestedPrice(900, 0.30, vatIncluded: false), 3000);
  });
}
