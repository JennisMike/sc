class ExchangeRateData {
  final String baseCurrency;
  final String targetCurrency;
  final double rate;
  final DateTime lastUpdated;

  ExchangeRateData({
    required this.baseCurrency,
    required this.targetCurrency,
    required this.rate,
    required this.lastUpdated,
  });

  factory ExchangeRateData.fromJson(Map<String, dynamic> json) {
    return ExchangeRateData(
      baseCurrency: json['base_currency'] as String,
      targetCurrency: json['target_currency'] as String,
      rate: (json['rate'] as num).toDouble(), // Ensure rate is double
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_currency': baseCurrency,
      'target_currency': targetCurrency,
      'rate': rate,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
