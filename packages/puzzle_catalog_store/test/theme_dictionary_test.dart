import 'package:puzzle_catalog_store/puzzle_catalog_store.dart';
import 'package:test/test.dart';

void main() {
  test('encodes low and high theme masks without using sign bit', () {
    final lowTheme = ThemeDictionaryV1.themes.first;
    final highTheme = ThemeDictionaryV1.themes[63];
    final mask = ThemeDictionaryV1.encode(<String>[lowTheme, highTheme]);

    expect(mask.low, greaterThan(0));
    expect(mask.high, greaterThan(0));
    expect(mask.low, inInclusiveRange(0, 0x7FFFFFFFFFFFFFFF));
    expect(mask.high, inInclusiveRange(0, 0x7FFFFFFFFFFFFFFF));
    expect(mask.unknownThemes, isEmpty);
  });
}
