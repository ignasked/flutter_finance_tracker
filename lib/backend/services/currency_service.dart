import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static Future<Map<String, double>> fetchExchangeRates(
      String baseCurrency) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedRates = prefs.getString('cachedExchangeRates');
    final lastUpdated = prefs.getInt('exchangeRatesLastUpdated');

    // Check if cached rates are available and not older than 24 hours
    if (cachedRates != null && lastUpdated != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastUpdated < 24 * 60 * 60 * 1000) {
        return Map<String, double>.from(json.decode(cachedRates));
      }
    }

    // Fetch new rates from the API
    final url = 'https://api.exchangerate-api.com/v4/latest/$baseCurrency';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final rates = (data['rates'] as Map<String, dynamic>).map<String, double>(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );

      // Cache the rates and timestamp
      await prefs.setString('cachedExchangeRates', json.encode(rates));
      await prefs.setInt(
          'exchangeRatesLastUpdated', DateTime.now().millisecondsSinceEpoch);

      return rates;
    } else {
      throw Exception('Failed to fetch exchange rates');
    }
  }
}
