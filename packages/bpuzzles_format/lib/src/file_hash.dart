import 'dart:io';

import 'package:crypto/crypto.dart';

Future<String> sha256File(File file) async {
  if (!await file.exists()) {
    throw FileSystemException('Datei nicht gefunden', file.path);
  }

  final digest = await sha256.bind(file.openRead()).first;
  return digest.toString();
}

bool isSha256Hex(String value) {
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(value.toLowerCase());
}
