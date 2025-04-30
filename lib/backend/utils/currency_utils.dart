import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyUtils {
  static const Map<String, String> predefinedCurrencies = {
    'USD': '\$', // United States Dollar
    'EUR': '€', // Euro
    'GBP': '£', // British Pound
    'JPY': '¥', // Japanese Yen
    'AUD': 'A\$', // Australian Dollar
    'CAD': 'C\$', // Canadian Dollar
    'CHF': 'CHF', // Swiss Franc
    'CNY': '¥', // Chinese Yuan
    'SEK': 'kr', // Swedish Krona
    'NZD': 'NZ\$', // New Zealand Dollar
  };

  final Map<String, double> exchangeRates;

  CurrencyUtils(this.exchangeRates);

  // Factory method to create a CurrencyUtils instance from an API response
  factory CurrencyUtils.fromApiResponse(Map<String, dynamic> response) {
    return CurrencyUtils(Map<String, double>.from(response['rates']));
  }

  // Convert an amount from one currency to another
  double convert(double amount, String fromCurrency, String toCurrency) {
    if (fromCurrency == toCurrency) {
      return amount;
    }

    final fromRate = exchangeRates[fromCurrency];
    final toRate = exchangeRates[toCurrency];

    if (fromRate == null || toRate == null) {
      throw Exception('Exchange rate not available for one of the currencies');
    }

    return amount * (toRate / fromRate);
  }

  // Get a list of supported currencies
  List<String> getSupportedCurrencies() {
    return exchangeRates.keys.toList();
  }

  // Check if a currency is supported
  bool isCurrencySupported(String currency) {
    return exchangeRates.containsKey(currency);
  }

  static double convertAmount(double amount, String fromCurrency,
      String toCurrency, Map<String, double> exchangeRates) {
    if (fromCurrency == toCurrency) {
      return amount;
    }

    final fromRate = exchangeRates[fromCurrency];
    final toRate = exchangeRates[toCurrency];

    if (fromRate == null || toRate == null) {
      throw Exception('Exchange rate not available for one of the currencies');
    }

    return amount * (toRate / fromRate);
  }
}
