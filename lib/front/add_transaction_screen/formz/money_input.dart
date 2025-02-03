import 'package:formz/formz.dart';

enum AmountValidationError { empty, invalid }

class MoneyInput extends FormzInput<String, AmountValidationError> {
  const MoneyInput.pure() : super.pure('');
  const MoneyInput.dirty([String value = '']) : super.dirty(value);

  @override
  AmountValidationError? validator(String value) {
    if (value.isEmpty) {
      return AmountValidationError.empty;
    }
    final number = double.tryParse(value);
    return number == null || number < 0 ? AmountValidationError.invalid : null;
  }
}
