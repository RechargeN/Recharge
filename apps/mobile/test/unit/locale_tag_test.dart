import 'package:flutter_test/flutter_test.dart';
import 'package:recharge/shared/primitives/locale/locale_tag.dart';

void main() {
  test('normalizes supported language script region subset independently', () {
    expect(LocaleTag.parse('RU').value, 'ru');
    expect(LocaleTag.parse('en-us'), LocaleTag.parse('EN-US'));
    expect(LocaleTag.parse('zh-hANT-tw').value, 'zh-Hant-TW');
    expect(LocaleTag.parse('es-419').value, 'es-419');
    expect(LocaleTag.parse('lv-LV').toString(), 'lv-LV');
    expect(
      LocaleTag.parse('EN-us').hashCode,
      LocaleTag.parse('en-US').hashCode,
    );
    // Parsing an identity neither checks translation availability nor infers
    // that a matching market or currency is enabled.
    expect(LocaleTag.parse('und').value, 'und');
  });

  test('fails rather than silently discarding unsupported parts', () {
    for (final value in [
      '',
      'e',
      'english',
      'en_US',
      'en-US-u-ca-gregory',
      'de-DE-1996',
      'en--US',
      'en-12',
      ' en',
      'en ',
      'en\n',
    ]) {
      expect(() => LocaleTag.parse(value), throwsFormatException);
    }
  });
}
