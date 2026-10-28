import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/cost_repository.dart';
import '../domain/cost_calculator.dart';
import '../models/app_settings.dart';
import '../models/ingredient.dart';
import '../models/menu.dart';

/// main.dart에서 로그인한 uid로 덮어쓴다.
final uidProvider = Provider<String>((ref) => throw UnimplementedError('uid 미설정'));

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final repositoryProvider = Provider<CostRepository>(
  (ref) => CostRepository(ref.watch(firestoreProvider), ref.watch(uidProvider)),
);

// ---------- 원본 데이터 (실시간 스트림) ----------

final ingredientsProvider = StreamProvider<List<Ingredient>>(
  (ref) => ref.watch(repositoryProvider).watchIngredients(),
);

final menusProvider = StreamProvider<List<Menu>>(
  (ref) => ref.watch(repositoryProvider).watchMenus(),
);

final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(repositoryProvider).watchSettings(),
);

// ---------- 파생 데이터 (계산 결과) ----------

/// 메뉴와 재료가 모두 도착했을 때만 계산한다.
final menuCostsProvider = Provider<AsyncValue<List<MenuCost>>>((ref) {
  final menusAsync = ref.watch(menusProvider);
  final ingredientsAsync = ref.watch(ingredientsProvider);
  final settingsAsync = ref.watch(settingsProvider);

  if (menusAsync.hasError) {
    return AsyncError<List<MenuCost>>(
        menusAsync.error!, menusAsync.stackTrace ?? StackTrace.current);
  }
  if (ingredientsAsync.hasError) {
    return AsyncError<List<MenuCost>>(
        ingredientsAsync.error!, ingredientsAsync.stackTrace ?? StackTrace.current);
  }
  if (settingsAsync.hasError) {
    return AsyncError<List<MenuCost>>(
        settingsAsync.error!, settingsAsync.stackTrace ?? StackTrace.current);
  }

  final menus = menusAsync.asData?.value;
  final ingredients = ingredientsAsync.asData?.value;
  final settings = settingsAsync.asData?.value;
  if (menus == null || ingredients == null || settings == null) {
    return const AsyncLoading<List<MenuCost>>();
  }

  final byId = {for (final i in ingredients) i.id: i};
  return AsyncData(menus
      .map((m) => CostCalculator.calculate(m, byId, vatIncluded: settings.vatIncluded))
      .toList());
});

/// 메뉴 하나의 계산 결과 (상세 화면용)
final menuCostProvider = Provider.family<MenuCost?, String>((ref, menuId) {
  final costs = ref.watch(menuCostsProvider).asData?.value;
  if (costs == null) return null;
  for (final c in costs) {
    if (c.menu.id == menuId) return c;
  }
  return null;
});

/// 재료를 쓰는 메뉴 이름 목록 (삭제 전 확인용)
final menusUsingIngredientProvider =
    Provider.family<List<String>, String>((ref, ingredientId) {
  final menus = ref.watch(menusProvider).asData?.value ?? const <Menu>[];
  return [
    for (final m in menus)
      if (m.recipe.any((r) => r.ingredientId == ingredientId)) m.name,
  ];
});

/// 재료를 레시피에 쓰는 반제품 이름 목록 (삭제 전 확인, 반제품 중첩 방지용)
final preparedUsingIngredientProvider =
    Provider.family<List<String>, String>((ref, ingredientId) {
  final ingredients = ref.watch(ingredientsProvider).asData?.value ?? const <Ingredient>[];
  return [
    for (final g in ingredients)
      if (g.recipe.any((r) => r.ingredientId == ingredientId)) g.name,
  ];
});
