class SalesChannel {
  const SalesChannel({required this.id, required this.name, required this.feeRate});

  final String id; // 메뉴의 채널별 판매가·레시피 적용 채널이 이 값을 가리킨다
  final String name;
  final double feeRate; // 0.1 = 10%

  factory SalesChannel.fromMap(Map<String, dynamic> m) {
    final name = m['name'] as String? ?? '';
    return SalesChannel(
      id: m['id'] as String? ?? name, // id가 없던 이전 데이터는 이름을 id로 쓴다
      name: name,
      feeRate: (m['feeRate'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'feeRate': feeRate};
}

class AppSettings {
  const AppSettings({
    required this.channels,
    required this.warningRate,
    required this.targetRate,
    required this.vatIncluded,
  });

  final List<SalesChannel> channels;
  final double warningRate; // 이 원가율 이상이면 경고 색상
  final double targetRate; // 적정 판매가 계산 기준
  final bool vatIncluded; // 판매가에 부가세 10%가 포함되어 있으면 true (일반과세자)

  /// 설정 문서가 아직 없을 때 쓰는 예시 기본값
  static const defaults = AppSettings(
    channels: [
      SalesChannel(id: '매장', name: '매장', feeRate: 0),
      SalesChannel(id: '배달앱', name: '배달앱', feeRate: 0.1),
    ],
    warningRate: 0.35,
    targetRate: 0.30,
    vatIncluded: true,
  );

  factory AppSettings.fromMap(Map<String, dynamic> m) {
    final raw = m['channels'] as List<dynamic>? ?? const [];
    return AppSettings(
      channels: raw
          .map((e) => SalesChannel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      warningRate: (m['warningRate'] as num?)?.toDouble() ?? defaults.warningRate,
      targetRate: (m['targetRate'] as num?)?.toDouble() ?? defaults.targetRate,
      vatIncluded: m['vatIncluded'] as bool? ?? defaults.vatIncluded,
    );
  }

  Map<String, dynamic> toMap() => {
        'channels': channels.map((c) => c.toMap()).toList(),
        'warningRate': warningRate,
        'targetRate': targetRate,
        'vatIncluded': vatIncluded,
      };
}
