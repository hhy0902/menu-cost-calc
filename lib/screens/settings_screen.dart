import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../models/app_settings.dart';
import '../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _ChannelRow {
  _ChannelRow(this.id, String name, double feeRate)
      : nameCtrl = TextEditingController(text: name),
        feeCtrl = TextEditingController(text: rateInput(feeRate));

  final String id; // 이름을 바꿔도 메뉴의 채널별 판매가·부자재 연결이 유지되도록
  final TextEditingController nameCtrl;
  final TextEditingController feeCtrl;

  void dispose() {
    nameCtrl.dispose();
    feeCtrl.dispose();
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _warningCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final List<_ChannelRow> _channels = [];
  bool _vatIncluded = AppSettings.defaults.vatIncluded;
  bool _loaded = false;

  /// 처음 도착한 설정값으로 한 번만 입력칸을 채운다.
  void _load(AppSettings s) {
    if (_loaded) return;
    _loaded = true;
    _warningCtrl.text = rateInput(s.warningRate);
    _targetCtrl.text = rateInput(s.targetRate);
    _vatIncluded = s.vatIncluded;
    _channels.addAll(s.channels.map((c) => _ChannelRow(c.id, c.name, c.feeRate)));
  }

  @override
  void dispose() {
    _warningCtrl.dispose();
    _targetCtrl.dispose();
    for (final c in _channels) {
      c.dispose();
    }
    super.dispose();
  }

  double _rate(TextEditingController c) => (double.tryParse(c.text.trim()) ?? 0) / 100;

  void _removeChannel(int index) {
    final row = _channels[index];
    setState(() => _channels.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final settings = AppSettings(
      warningRate: _rate(_warningCtrl),
      targetRate: _rate(_targetCtrl),
      vatIncluded: _vatIncluded,
      channels: [
        for (final c in _channels)
          SalesChannel(id: c.id, name: c.nameCtrl.text.trim(), feeRate: _rate(c.feeCtrl)),
      ],
    );
    // 서버 확인을 기다리면 오프라인에서 멈추므로 기다리지 않는다 (로컬에는 바로 반영됨)
    final messenger = ScaffoldMessenger.of(context);
    ref.read(repositoryProvider).saveSettings(settings).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    });
    messenger.showSnackBar(const SnackBar(content: Text('저장했습니다')));
  }

  String? _validateRate(String? v, {bool allowZero = false}) {
    final r = double.tryParse((v ?? '').trim());
    if (r == null || r >= 100 || r < 0 || (!allowZero && r == 0)) {
      return allowZero ? '0 이상 100 미만' : '0 초과 100 미만';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('불러오기 실패: $e')),
        data: (s) {
          _load(s);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('원가율 기준', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _warningCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '경고 원가율',
                    helperText: '이 값 이상인 메뉴는 빨간색으로 표시',
                    suffixText: '%',
                  ),
                  validator: _validateRate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '목표 원가율',
                    helperText: '적정 판매가 계산 기준',
                    suffixText: '%',
                  ),
                  validator: _validateRate,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('판매가에 부가세 10% 포함'),
                  subtitle: const Text('일반과세자는 켜기. 판매가 ÷ 1.1을 매출로 계산'),
                  value: _vatIncluded,
                  onChanged: (v) => setState(() => _vatIncluded = v),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('판매 채널', style: theme.textTheme.titleMedium)),
                    TextButton.icon(
                      onPressed: () => setState(() => _channels.add(_ChannelRow(
                          DateTime.now().microsecondsSinceEpoch.toString(), '', 0))),
                      icon: const Icon(Icons.add),
                      label: const Text('채널 추가'),
                    ),
                  ],
                ),
                for (var i = 0; i < _channels.length; i++)
                  Padding(
                    key: ObjectKey(_channels[i]),
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _channels[i].nameCtrl,
                            decoration: const InputDecoration(labelText: '채널 이름'),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? '이름 입력' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _channels[i].feeCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: '수수료',
                              suffixText: '%',
                            ),
                            validator: (v) => _validateRate(v, allowZero: true),
                          ),
                        ),
                        IconButton(
                          tooltip: '채널 삭제',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _channels.length > 1 ? () => _removeChannel(i) : null,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _save,
                  child: const Text('저장'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
