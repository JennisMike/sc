import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exchange_rate_model.dart';

class ExchangeService {
  final SupabaseClient _supabaseClient = Supabase.instance.client;
  static const String _exchangeRateCacheKey = 'cached_exchange_rate';
  static const String _lastFetchTimestampKey = 'last_exchange_rate_fetch_timestamp';
  // Cache duration: 55 minutes, to be slightly less than the typical 1-hour update cycle
  static const Duration _cacheValidityDuration = Duration(minutes: 55);

  Future<ExchangeRateData?> getExchangeRate({ 
    String baseCurrency = 'CNY',
    String targetCurrency = 'XAF',
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load from cache
    final cachedRateString = prefs.getString(_exchangeRateCacheKey);
    final lastFetchTimestampString = prefs.getString(_lastFetchTimestampKey);

    if (cachedRateString != null && lastFetchTimestampString != null) {
      final lastFetchTimestamp = DateTime.parse(lastFetchTimestampString);
      if (DateTime.now().difference(lastFetchTimestamp) < _cacheValidityDuration) {
        // Cache is valid
        final cachedData = ExchangeRateData(
          baseCurrency: baseCurrency, // Assuming cached rate is for CNY/XAF
          targetCurrency: targetCurrency,
          rate: double.parse(cachedRateString),
          lastUpdated: lastFetchTimestamp, // Use fetch timestamp as a proxy for lastUpdated from cache
        );
        print('[ExchangeService] Using cached rate: ${cachedData.rate}');
        return cachedData;
      }
    }

    // Cache is invalid or not present, fetch from Supabase
    print('[ExchangeService] Cache invalid or not found. Fetching from Supabase...');
    try {
      final response = await _supabaseClient
          .from('exchange_rates')
          .select('rate, last_updated')
          .eq('base_currency', baseCurrency)
          .eq('target_currency', targetCurrency)
          .order('last_updated', ascending: false)
          .limit(1)
          .single(); // Use .single() to get one record or throw error

      final rateValue = (response['rate'] as num).toDouble();
      final lastUpdated = DateTime.parse(response['last_updated'] as String);

      final exchangeRateData = ExchangeRateData(
        baseCurrency: baseCurrency,
        targetCurrency: targetCurrency,
        rate: rateValue,
        lastUpdated: lastUpdated,
      );

      // Update cache
      await prefs.setString(_exchangeRateCacheKey, rateValue.toString());
      await prefs.setString(_lastFetchTimestampKey, DateTime.now().toIso8601String());
      print('[ExchangeService] Fetched and cached new rate: ${exchangeRateData.rate}');
      return exchangeRateData;

    } catch (e) {
      print('[ExchangeService] Error fetching exchange rate from Supabase: $e');
      // Optionally, return stale cache if available and error occurs
      if (cachedRateString != null) {
        print('[ExchangeService] Returning stale cached rate due to fetch error.');
         final lastFetchTimestamp = lastFetchTimestampString != null 
            ? DateTime.parse(lastFetchTimestampString) 
            : DateTime.now().subtract(const Duration(days: 1)); // Fallback timestamp
        return ExchangeRateData(
          baseCurrency: baseCurrency,
          targetCurrency: targetCurrency,
          rate: double.parse(cachedRateString),
          lastUpdated: lastFetchTimestamp, 
        );
      }
      return null; // No cache and fetch failed
    }
  }
}
