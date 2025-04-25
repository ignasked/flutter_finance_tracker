import 'package:formz/formz.dart';

enum TitleValidationError { empty }

class TitleInput extends FormzInput<String, TitleValidationError> {
  const TitleInput.pure() : super.pure('');
  const TitleInput.dirty([String value = '']) : super.dirty(value);

  @override
  TitleValidationError? validator(String value) {
    return value.isEmpty ? TitleValidationError.empty : null;
  }
}
