import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/cost_calculator.dart';
import '../models/ingredient.dart';
import '../models/menu.dart';
import '../models/unit_type.dart';
import '../providers/providers.dart';

class IngredientEditScreen extends ConsumerStatefulWidget {
  const IngredientEditScreen({super.key, this.ingredient});

  final Ingredient? ingredient; // null이면 새 재료

  @override
  ConsumerState<IngredientEditScreen> createState() => _IngredientEditScreenState();
}

/// 반제품 레시피 한 줄
class _SubRow {
  _SubRow([this.ingredientId, String amount = ''])
      : amountCtrl = TextEditingController(text: amount);

  String? ingredientId;
  final TextEditingController amountCtrl;
}

class _IngredientEditScreenState extends ConsumerState<IngredientEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.ingredient?.name ?? '');
  late final _amountCtrl = TextEditingController(
    text: widget.ingredient == null ? '' : amountText(widget.ingredient!.purchaseAmount),
  );
  late final _priceCtrl =
      TextEditingController(text: widget.ingredient?.purchasePrice.toString() ?? '');
  late UnitType _unit = widget.ingredient?.unit ?? UnitType.g;
  late bool _prepared = widget.ingredient?.isPrepared ?? false;
  late final List<_SubRow> _rows = [
    for (final r in widget.ingredient?.recipe ?? const <RecipeItem>[])
      _SubRow(r.ingredientId, amountText(r.amount)),
  ];
  bool _saving = false;

  bool get _isNew => widget.ingredient == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    for (final r in _rows) {
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  Ingredient _draft() => Ingredient(
        id: widget.ingredient?.id ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unit,
        purchaseAmount: double.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0,
        purchasePrice:
            _prepared ? 0 : int.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0,
        recipe: [
          if (_prepared)
            for (final r in _rows)
              if (r.ingredientId != null)
                RecipeItem(
                  ingredientId: r.ingredientId!,
                  amount: double.tryParse(r.amountCtrl.text.replaceAll(',', '').trim()) ?? 0,
                ),
        ],
      );

  void _removeRow(int index) {
    final row = _rows[index];
    setState(() => _rows.removeAt(index));
    // 위젯이 트리에서 빠진 다음 프레임에 정리해야 오류가 없다
    WidgetsBinding.instance.addPostFrameCallback((_) => row.amountCtrl.dispose());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final draft = _draft();
    if (_prepared && draft.recipe.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('레시피에 재료를 하나 이상 넣으세요')));
      return;
    }
    setState(() => _saving = true); // 화면이 닫히는 동안 두 번 저장되지 않게
    // Firestore 쓰기는 로컬에 바로 반영되지만 Future는 서버 확인 후에 끝난다.
    // 기다리면 오프라인에서 멈추므로 기다리지 않고 닫는다.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).saveIngredient(draft).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    });
    Navigator.of(context).pop();
  }

  Future<void> _delete(List<String> menus, List<String> prepared) async {
    final message = menus.isEmpty && prepared.isEmpty
        ? '${widget.ingredient!.name}을(를) 삭제할까요?'
        : [
            if (menus.isNotEmpty) '다음 메뉴에서 사용 중입니다: ${menus.join(', ')}',
            if (prepared.isNotEmpty) '다음 반제품에서 사용 중입니다: ${prepared.join(', ')}',
            '삭제하면 원가에서 빠지고 "재료 확인 필요"로 표시됩니다.',
          ].join('\n');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('재료 삭제'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).deleteIngredient(widget.ingredient!.id).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.ingredient?.id;
    final usedInMenus =
        id == null ? const <String>[] : ref.watch(menusUsingIngredientProvider(id));
    final usedInPrepared =
        id == null ? const <String>[] : ref.watch(preparedUsingIngredientProvider(id));
    final unitChanged = !_isNew &&
        _unit != widget.ingredient!.unit &&
        (usedInMenus.isNotEmpty || usedInPrepared.isNotEmpty);
    final ingredients = ref.watch(ingredientsProvider).asData?.value ?? const <Ingredient>[];
    final byId = {for (final i in ingredients) i.id: i};
    // 반제품 레시피에는 자기 자신과 다른 반제품을 넣을 수 없다
    final choices = [
      for (final g in ingredients)
        if (!g.isPrepared && g.id != id) g,
    ];
    final draft = _draft();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '재료 추가' : '재료 수정'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(usedInMenus, usedInPrepared),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '재료 이름'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<UnitType>(
              segments: [
                for (final u in UnitType.values) ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            if (unitChanged)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '단위를 바꾸면 이 재료를 쓰는 메뉴·반제품의 사용량도 새 단위로 고쳐야 합니다.',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('직접 만드는 재료 (반제품)'),
              subtitle: Text(usedInPrepared.isNotEmpty && !_prepared
                  ? '반제품 ${usedInPrepared.join(', ')}에 들어가는 재료라 반제품으로 바꿀 수 없습니다'
                  : '시럽·소스처럼 직접 만들면 레시피와 완성량으로 단가를 계산'),
              value: _prepared,
              // 반제품 안에 반제품이 들어가지 않도록 막는다
              onChanged: usedInPrepared.isNotEmpty && !_prepared
                  ? null
                  : (v) => setState(() => _prepared = v),
            ),
            if (_prepared) ...[
              const SizedBox(height: 8),
              Text('레시피', style: theme.textTheme.titleMedium),
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('먼저 사 온 재료를 등록하세요.'),
                ),
              for (var i = 0; i < _rows.length; i++) _buildRow(i, choices, byId),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: choices.isEmpty ? null : () => setState(() => _rows.add(_SubRow())),
                  icon: const Icon(Icons.add),
                  label: const Text('재료 추가'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _prepared ? '완성량' : '구매량',
                helperText: _prepared ? '위 레시피로 만들었을 때 나오는 양' : null,
                suffixText: _unit.label,
              ),
              validator: (v) {
                final a = double.tryParse((v ?? '').replaceAll(',', '').trim());
                return (a == null || a <= 0) ? '0보다 큰 값을 입력하세요' : null;
              },
              onChanged: (_) => setState(() {}),
            ),
            if (!_prepared) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '구매가', suffixText: '원'),
                validator: (v) {
                  final p = int.tryParse((v ?? '').replaceAll(',', '').trim());
                  return (p == null || p < 0) ? '구매가를 입력하세요' : null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('단위당 단가'),
                trailing: Text(
                  '${unitWon(CostCalculator.unitCostOf(draft, byId))} / ${_unit.label}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장 중...' : '저장'),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(int index, List<Ingredient> choices, Map<String, Ingredient> byId) {
    final row = _rows[index];
    final selected = byId[row.ingredientId];
    final valid = choices.any((g) => g.id == row.ingredientId);
    return Padding(
      key: ObjectKey(row), // 줄을 지워도 다른 줄의 입력 상태가 섞이지 않게
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: valid ? row.ingredientId : null, // 삭제된 재료면 null -> 다시 선택
              isExpanded: true,
              decoration: const InputDecoration(labelText: '재료'),
              items: [
                for (final g in choices)
                  DropdownMenuItem(value: g.id, child: Text('${g.name} (${g.unit.label})')),
              ],
              onChanged: (v) => setState(() => row.ingredientId = v),
              validator: (v) => v == null ? '재료를 선택하세요' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '사용량', suffixText: selected?.unit.label),
              validator: (v) {
                final a = double.tryParse((v ?? '').replaceAll(',', '').trim());
                return (a == null || a <= 0) ? '0보다 크게' : null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            tooltip: '이 재료 빼기',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _removeRow(index),
          ),
        ],
      ),
    );
  }
}
