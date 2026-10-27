import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../domain/cost_calculator.dart';
import '../models/app_settings.dart';
import '../models/ingredient.dart';
import '../models/menu.dart';
import '../providers/providers.dart';

class MenuEditScreen extends ConsumerStatefulWidget {
  const MenuEditScreen({super.key, this.menu});

  final Menu? menu; // null이면 새 메뉴

  @override
  ConsumerState<MenuEditScreen> createState() => _MenuEditScreenState();
}

class _RecipeRow {
  _RecipeRow([this.ingredientId, String amount = ''])
      : amountCtrl = TextEditingController(text: amount);

  String? ingredientId;
  final TextEditingController amountCtrl;
}

class _MenuEditScreenState extends ConsumerState<MenuEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.menu?.name ?? '');
  late final _priceCtrl = TextEditingController(text: widget.menu?.price.toString() ?? '');
  late final List<_RecipeRow> _rows = [
    for (final r in widget.menu?.recipe ?? const <RecipeItem>[])
      _RecipeRow(r.ingredientId, amountText(r.amount)),
  ];
  bool _saving = false;

  bool get _isNew => widget.menu == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    for (final r in _rows) {
      r.amountCtrl.dispose();
    }
    super.dispose();
  }

  Menu _buildMenu() => Menu(
        id: widget.menu?.id ?? '',
        name: _nameCtrl.text.trim(),
        price: int.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0,
        recipe: [
          for (final r in _rows)
            if (r.ingredientId != null)
              RecipeItem(
                ingredientId: r.ingredientId!,
                amount: double.tryParse(r.amountCtrl.text.trim()) ?? 0,
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
    setState(() => _saving = true); // 화면이 닫히는 동안 두 번 저장되지 않게
    // Firestore 쓰기는 로컬에 바로 반영되지만 Future는 서버 확인 후에 끝난다.
    // 기다리면 오프라인에서 멈추므로 기다리지 않고 닫는다.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).saveMenu(_buildMenu()).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    });
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('메뉴 삭제'),
        content: Text('${widget.menu!.name}을(를) 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).deleteMenu(widget.menu!.id).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    });
    // 상세 화면까지 닫고 대시보드로
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = ref.watch(ingredientsProvider).asData?.value ?? const <Ingredient>[];
    final vatIncluded =
        (ref.watch(settingsProvider).asData?.value ?? AppSettings.defaults).vatIncluded;
    final byId = {for (final i in ingredients) i.id: i};
    final preview = CostCalculator.calculate(_buildMenu(), byId, vatIncluded: vatIncluded);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '메뉴 추가' : '메뉴 수정'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
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
              decoration: const InputDecoration(labelText: '메뉴 이름'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '판매가', suffixText: '원'),
              validator: (v) {
                final p = int.tryParse((v ?? '').replaceAll(',', '').trim());
                return (p == null || p <= 0) ? '판매가를 입력하세요' : null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text('레시피', style: theme.textTheme.titleMedium),
            if (ingredients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('먼저 식자재 탭에서 재료를 등록하세요.'),
              ),
            for (var i = 0; i < _rows.length; i++) _buildRow(i, ingredients, byId),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    ingredients.isEmpty ? null : () => setState(() => _rows.add(_RecipeRow())),
                icon: const Icon(Icons.add),
                label: const Text('재료 추가'),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: Text('예상 원가 ${won(preview.total)}'),
                trailing: Text(
                  '원가율 ${percent(preview.costRate)}',
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

  Widget _buildRow(int index, List<Ingredient> ingredients, Map<String, Ingredient> byId) {
    final row = _rows[index];
    final selected = byId[row.ingredientId];
    return Padding(
      key: ObjectKey(row), // 줄을 지워도 다른 줄의 입력 상태가 섞이지 않게
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: selected?.id, // 삭제된 재료면 null -> 다시 선택
              isExpanded: true,
              decoration: const InputDecoration(labelText: '재료'),
              items: [
                for (final g in ingredients)
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
                final a = double.tryParse((v ?? '').trim());
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
