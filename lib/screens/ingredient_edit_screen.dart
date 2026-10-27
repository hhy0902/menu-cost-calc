import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/ingredient.dart';
import '../models/unit_type.dart';
import '../providers/providers.dart';

class IngredientEditScreen extends ConsumerStatefulWidget {
  const IngredientEditScreen({super.key, this.ingredient});

  final Ingredient? ingredient; // null이면 새 재료

  @override
  ConsumerState<IngredientEditScreen> createState() => _IngredientEditScreenState();
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
  bool _saving = false;

  bool get _isNew => widget.ingredient == null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Ingredient _draft() => Ingredient(
        id: widget.ingredient?.id ?? '',
        name: _nameCtrl.text.trim(),
        unit: _unit,
        purchaseAmount: double.tryParse(_amountCtrl.text.trim()) ?? 0,
        purchasePrice: int.tryParse(_priceCtrl.text.replaceAll(',', '').trim()) ?? 0,
      );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true); // 화면이 닫히는 동안 두 번 저장되지 않게
    // Firestore 쓰기는 로컬에 바로 반영되지만 Future는 서버 확인 후에 끝난다.
    // 기다리면 오프라인에서 멈추므로 기다리지 않고 닫는다.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).saveIngredient(_draft()).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    });
    Navigator.of(context).pop();
  }

  Future<void> _delete(List<String> usedIn) async {
    final message = usedIn.isEmpty
        ? '${widget.ingredient!.name}을(를) 삭제할까요?'
        : '다음 메뉴에서 사용 중입니다: ${usedIn.join(', ')}\n삭제하면 해당 메뉴에 "삭제된 재료"로 표시됩니다.';
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
    final usedIn = _isNew
        ? const <String>[]
        : ref.watch(menusUsingIngredientProvider(widget.ingredient!.id));
    final unitChanged = !_isNew && _unit != widget.ingredient!.unit && usedIn.isNotEmpty;
    final draft = _draft();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '재료 추가' : '재료 수정'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(usedIn),
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
                  '단위를 바꾸면 이 재료를 쓰는 메뉴의 사용량도 새 단위로 고쳐야 합니다.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: '구매량', suffixText: _unit.label),
              validator: (v) {
                final a = double.tryParse((v ?? '').trim());
                return (a == null || a <= 0) ? '0보다 큰 값을 입력하세요' : null;
              },
              onChanged: (_) => setState(() {}),
            ),
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
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('단위당 단가'),
                trailing: Text(
                  '${unitWon(draft.unitCost)} / ${_unit.label}',
                  style: Theme.of(context).textTheme.titleMedium,
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
}
