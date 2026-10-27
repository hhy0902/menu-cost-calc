enum UnitType {
  g('g'),
  ml('ml'),
  ea('개');

  const UnitType(this.label);
  final String label;

  static UnitType fromName(String? name) =>
      UnitType.values.firstWhere((u) => u.name == name, orElse: () => UnitType.g);
}
