import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exchange_rate_model.dart';
import '../services/exchange_service.dart';

// Provider for the ExchangeService instance
final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  return ExchangeService();
});

// FutureProvider to fetch and provide the exchange rate data
// This will fetch CNY to XAF by default.
final exchangeRateProvider = FutureProvider<ExchangeRateData?>((ref) async {
  final service = ref.watch(exchangeServiceProvider);
  // The service defaults to CNY/XAF, but we can be explicit if needed.
  return service.getExchangeRate(); 
});
