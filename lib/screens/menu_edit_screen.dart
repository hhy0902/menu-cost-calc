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

  final Menu? menu; // null이거나 id가 비어 있으면(복제) 새 메뉴

  @override
  ConsumerState<MenuEditScreen> createState() => _MenuEditScreenState();
}

class _RecipeRow {
  _RecipeRow([this.ingredientId, String amount = '', Iterable<String> channelIds = const []])
      : amountCtrl = TextEditingController(text: amount),
        channelIds = {...channelIds};

  String? ingredientId;
  final TextEditingController amountCtrl;
  final Set<String> channelIds; // 비어 있으면 모든 채널
}

class _MenuEditScreenState extends ConsumerState<MenuEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.menu?.name ?? '');
  late final _priceCtrl = TextEditingController(text: widget.menu?.price.toString() ?? '');
  late final List<_RecipeRow> _rows = [
    for (final r in widget.menu?.recipe ?? const <RecipeItem>[])
      _RecipeRow(r.ingredientId, amountText(r.amount), r.channelIds),
  ];
  final Map<String, TextEditingController> _channelPriceCtrls = {}; // 채널 id -> 입력칸
  bool _saving = false;

  bool get _isNew => widget.menu == null || widget.menu!.id.isEmpty;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    for (final r in _rows) {
      r.amountCtrl.dispose();
    }
    for (final c in _channelPriceCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 채널 목록은 설정이 도착한 뒤에 알 수 있어서 입력칸을 필요할 때 만든다
  TextEditingController _channelPriceCtrl(String channelId) => _channelPriceCtrls.putIfAbsent(
        channelId,
        () => TextEditingController(
            text: widget.menu?.channelPrices[channelId]?.toString() ?? ''),
      );

  Map<String, int> _channelPrices() {
    // 화면에 없는 채널(아직 설정을 못 받았거나 삭제된 채널)의 기존 값은 그대로 둔다
    final prices = {...?widget.menu?.channelPrices};
    for (final e in _channelPriceCtrls.entries) {
      final p = int.tryParse(e.value.text.replaceAll(',', '').trim());
      if (p == null || p <= 0) {
        prices.remove(e.key);
      } else {
        prices[e.key] = p;
      }
    }
    return prices;
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
                amount: double.tryParse(r.amountCtrl.text.replaceAll(',', '').trim()) ?? 0,
                channelIds: r.channelIds.toList(),
              ),
        ],
        channelPrices: _channelPrices(),
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
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.asData?.value ?? AppSettings.defaults;
    final channels = settings.channels;
    final byId = {for (final i in ingredients) i.id: i};
    final preview =
        CostCalculator.calculate(_buildMenu(), byId, vatIncluded: settings.vatIncluded);
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
            const SizedBox(height: 16),
            Text('채널별 판매가 (비우면 기본 판매가)', style: theme.textTheme.bodySmall),
            for (final ch in channels)
              TextFormField(
                key: ValueKey('price-${ch.id}'),
                controller: _channelPriceCtrl(ch.id),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: ch.name,
                  // 비어 있을 때도 기본가가 보이도록 라벨을 항상 위에 둔다
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: _priceCtrl.text.trim().isEmpty ? null : '기본 ${_priceCtrl.text.trim()}',
                  suffixText: '원',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final p = int.tryParse(v.replaceAll(',', '').trim());
                  return (p == null || p <= 0) ? '0보다 크게 입력하거나 비우세요' : null;
                },
              ),
            const SizedBox(height: 24),
            Text('레시피', style: theme.textTheme.titleMedium),
            if (ingredients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('먼저 식자재 탭에서 재료를 등록하세요.'),
              ),
            for (var i = 0; i < _rows.length; i++)
              _buildRow(i, ingredients, byId, channels, settingsAsync.hasValue),
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
                subtitle: _rows.any((r) => r.channelIds.isNotEmpty)
                    ? const Text('채널 전용 부자재는 상세 화면의 채널별 순이익에 반영')
                    : null,
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

  Widget _buildRow(int index, List<Ingredient> ingredients, Map<String, Ingredient> byId,
      List<SalesChannel> channels, bool channelsLoaded) {
    final row = _rows[index];
    final selected = byId[row.ingredientId];
    bool exists(String id) => channels.any((c) => c.id == id);
    // 선택한 채널이 모두 삭제되면 이 줄은 어느 채널 계산에도 들어가지 않는다
    // (설정이 오기 전에는 기본 채널로 판단하게 되므로 경고하지 않는다)
    final orphan = channelsLoaded && row.channelIds.isNotEmpty && !row.channelIds.any(exists);
    return Padding(
      key: ObjectKey(row), // 줄을 지워도 다른 줄의 입력 상태가 섞이지 않게
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRowFields(index, row, ingredients, selected),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(row.channelIds.isEmpty ? '모든 채널' : '선택한 채널만',
                  style: Theme.of(context).textTheme.bodySmall),
              for (final ch in channels)
                FilterChip(
                  label: Text(ch.name),
                  selected: row.channelIds.contains(ch.id),
                  onSelected: (on) => setState(() {
                    if (channelsLoaded) row.channelIds.removeWhere((id) => !exists(id));
                    on ? row.channelIds.add(ch.id) : row.channelIds.remove(ch.id);
                  }),
                ),
            ],
          ),
          if (orphan)
            Text(
              '삭제된 채널에만 적용되어 계산에서 빠집니다. 채널을 다시 고르세요.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildRowFields(
      int index, _RecipeRow row, List<Ingredient> ingredients, Ingredient? selected) {
    return Row(
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
    );
  }
}
