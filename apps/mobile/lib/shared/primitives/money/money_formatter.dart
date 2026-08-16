import 'currency_metadata.dart';
import 'money.dart';

/// Locale-aware formatter that operates only on integer minor units.
abstract final class MoneyFormatter {
  static String format(
    Money money, {
    String localeTag = 'en',
    bool includeCurrency = true,
    bool useSymbol = true,
  }) {
    final CurrencyMetadata? metadata = CurrencyMetadata.tryFor(money.currency);
    if (metadata == null) {
      throw FormatException('Unknown currency: ${money.currency.value}');
    }

    final bool decimalComma = _usesDecimalComma(localeTag);
    final String decimalSeparator = decimalComma ? ',' : '.';
    final String groupingSeparator = decimalComma ? '\u00a0' : ',';
    final int exponent = metadata.minorUnitExponent;
    final int scale = _pow10(exponent);
    final int absolute = money.minorUnits.abs();
    final String whole = _group(absolute ~/ scale, groupingSeparator);
    final String fraction = exponent == 0
        ? ''
        : '$decimalSeparator${(absolute % scale).toString().padLeft(exponent, '0')}';
    final String number = '$whole$fraction';
    if (!includeCurrency) {
      return '${money.isNegative ? '-' : ''}$number';
    }

    final String label = useSymbol ? metadata.symbol : metadata.code.value;
    return decimalComma
        ? '${money.isNegative ? '-' : ''}$number\u00a0$label'
        : '${money.isNegative ? '-' : ''}$label$number';
  }

  /// Canonical decimal representation for URLs and local wire adapters.
  /// It is derived with integer arithmetic and never passes through [double].
  static String decimal(
    Money money, {
    String decimalSeparator = '.',
    bool trimTrailingZeros = true,
  }) {
    final CurrencyMetadata? metadata = CurrencyMetadata.tryFor(money.currency);
    if (metadata == null) {
      throw FormatException('Unknown currency: ${money.currency.value}');
    }
    final int exponent = metadata.minorUnitExponent;
    final int scale = _pow10(exponent);
    final int absolute = money.minorUnits.abs();
    final String sign = money.isNegative ? '-' : '';
    final String whole = (absolute ~/ scale).toString();
    if (exponent == 0) return '$sign$whole';
    String fraction = (absolute % scale).toString().padLeft(exponent, '0');
    if (trimTrailingZeros) {
      fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
    }
    return fraction.isEmpty
        ? '$sign$whole'
        : '$sign$whole$decimalSeparator$fraction';
  }

  /// Presentation-only projection for widgets such as [Slider].
  static double majorUnitsForUi(Money money) {
    final CurrencyMetadata? metadata = CurrencyMetadata.tryFor(money.currency);
    if (metadata == null) {
      throw FormatException('Unknown currency: ${money.currency.value}');
    }
    return money.minorUnits / _pow10(metadata.minorUnitExponent);
  }

  static int _pow10(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index += 1) {
      value *= 10;
    }
    return value;
  }

  static String _group(int whole, String separator) {
    final String digits = whole.toString();
    final StringBuffer output = StringBuffer();
    for (var index = 0; index < digits.length; index += 1) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        output.write(separator);
      }
      output.write(digits[index]);
    }
    return output.toString();
  }

  static bool _usesDecimalComma(String localeTag) {
    final String language = localeTag
        .trim()
        .toLowerCase()
        .split(RegExp('[-_]'))
        .first;
    return const <String>{'lv', 'lt', 'et', 'ru'}.contains(language);
  }
}
