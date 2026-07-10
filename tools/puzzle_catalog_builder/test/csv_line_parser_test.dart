import 'package:puzzle_catalog_builder/src/csv_line_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses quoted commas and escaped quotes', () {
    expect(parseCsvLine('a,"b,c","d""e"'), <String>['a', 'b,c', 'd"e']);
  });
}
