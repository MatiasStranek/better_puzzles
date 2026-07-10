List<String> parseCsvLine(String line) {
  final fields = <String>[];
  final buffer = StringBuffer();
  var inQuotes = false;

  for (var index = 0; index < line.length; index++) {
    final char = line[index];

    if (char == '"') {
      if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
        buffer.write('"');
        index++;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }

    if (char == ',' && !inQuotes) {
      fields.add(buffer.toString());
      buffer.clear();
      continue;
    }

    buffer.write(char);
  }

  if (inQuotes) {
    throw const FormatException('Nicht geschlossenes CSV-Anführungszeichen');
  }

  fields.add(buffer.toString());
  return fields;
}
