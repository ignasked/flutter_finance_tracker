class CurrencyUtils {
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
}
