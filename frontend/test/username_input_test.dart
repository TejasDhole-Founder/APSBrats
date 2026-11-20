import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String typed(String input) {
  var value = const TextEditingValue();
  for (final ch in input.split('')) {
    var next = TextEditingValue(
      text: value.text + ch,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    for (final f in usernameInputFormatters) {
      next = f.formatEditUpdate(value, next);
    }
    value = next;
  }
  return value.text;
}

void main() {
  test('keeps letters, digits and underscores, lowercased', () {
    expect(typed('Tejas_Dhole_99'), 'tejas_dhole_99');
  });

  test('drops periods, @, spaces and other symbols as you type', () {
    expect(typed('@te.jas-d#hole!'), 'tejasdhole');
  });

  test('stops at 20 characters', () {
    expect(typed('a' * 40).length, 20);
  });
}
