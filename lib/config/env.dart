class Env {
  static const String mistralApiKey = String.fromEnvironment(
    'MISTRAL_API_KEY',
    defaultValue: '',
  );
}
