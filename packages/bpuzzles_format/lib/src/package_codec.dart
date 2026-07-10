import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'file_hash.dart';
import 'manifest.dart';

const List<int> _magic = <int>[
  0x42, // B
  0x50, // P
  0x5A, // Z
  0x50, // P
  0x4B, // K
  0x47, // G
  0x31, // 1
  0x0A, // newline
];

const int _fixedHeaderLength = 8 + 4 + 8;
const int _maxManifestBytes = 4 * 1024 * 1024;

class BPuzzlesPackageHeader {
  const BPuzzlesPackageHeader({
    required this.manifest,
    required this.databaseOffset,
    required this.databaseLength,
    required this.packageLength,
  });

  final BPuzzlesManifest manifest;
  final int databaseOffset;
  final int databaseLength;
  final int packageLength;
}

class BPuzzlesPackageReader {
  const BPuzzlesPackageReader();

  Future<BPuzzlesPackageHeader> inspect(File packageFile) async {
    if (!await packageFile.exists()) {
      throw FileSystemException('Paketdatei nicht gefunden', packageFile.path);
    }

    final packageLength = await packageFile.length();
    final handle = await packageFile.open();

    try {
      final magic = await _readExactly(handle, _magic.length);
      if (!_sameBytes(magic, _magic)) {
        throw const FormatException(
          'Keine gültige .bpuzzles-Datei (Magic stimmt nicht)',
        );
      }

      final manifestLengthBytes = await _readExactly(handle, 4);
      final databaseLengthBytes = await _readExactly(handle, 8);
      final manifestLength = ByteData.sublistView(
        Uint8List.fromList(manifestLengthBytes),
      ).getUint32(0, Endian.little);
      final databaseLength = ByteData.sublistView(
        Uint8List.fromList(databaseLengthBytes),
      ).getUint64(0, Endian.little);

      if (manifestLength <= 0 || manifestLength > _maxManifestBytes) {
        throw FormatException('Ungültige Manifestgröße: $manifestLength Bytes');
      }
      if (databaseLength <= 0) {
        throw const FormatException(
          'Das Paket enthält keine ObjectBox-Datenbank',
        );
      }

      final manifestBytes = await _readExactly(handle, manifestLength);
      final manifestJson = jsonDecode(utf8.decode(manifestBytes));
      if (manifestJson is! Map) {
        throw const FormatException('manifest.json ist kein JSON-Objekt');
      }

      final manifestMap = manifestJson.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      final manifest = BPuzzlesManifest.fromJson(manifestMap);
      final databaseOffset = _fixedHeaderLength + manifestLength;
      final expectedLength = databaseOffset + databaseLength;

      if (expectedLength != packageLength) {
        throw FormatException(
          'Paketgröße stimmt nicht: erwartet $expectedLength, '
          'vorhanden $packageLength',
        );
      }
      if (manifest.database.sizeBytes != databaseLength) {
        throw FormatException(
          'Manifest und Paketkopf melden unterschiedliche '
          'Datenbankgrößen',
        );
      }

      return BPuzzlesPackageHeader(
        manifest: manifest,
        databaseOffset: databaseOffset,
        databaseLength: databaseLength,
        packageLength: packageLength,
      );
    } finally {
      await handle.close();
    }
  }

  Future<File> extractDatabase({
    required File packageFile,
    required BPuzzlesPackageHeader header,
    required File targetFile,
    void Function(int copiedBytes, int totalBytes)? onProgress,
  }) async {
    await targetFile.parent.create(recursive: true);

    final temporaryFile = File('${targetFile.path}.partial');
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    final sink = temporaryFile.openWrite();
    var copied = 0;

    try {
      try {
        final end = header.databaseOffset + header.databaseLength;
        await for (final chunk in packageFile.openRead(
          header.databaseOffset,
          end,
        )) {
          sink.add(chunk);
          copied += chunk.length;
          onProgress?.call(copied, header.databaseLength);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (_) {
      await _deleteIfExists(temporaryFile);
      rethrow;
    }

    if (copied != header.databaseLength) {
      await _deleteIfExists(temporaryFile);
      throw FileSystemException(
        'Datenbank wurde nicht vollständig extrahiert',
        packageFile.path,
      );
    }

    final actualHash = await sha256File(temporaryFile);
    if (actualHash.toLowerCase() !=
        header.manifest.database.sha256.toLowerCase()) {
      await _deleteIfExists(temporaryFile);
      throw FormatException('SHA-256-Prüfung fehlgeschlagen: $actualHash');
    }

    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    return temporaryFile.rename(targetFile.path);
  }
}

class BPuzzlesPackageWriter {
  const BPuzzlesPackageWriter();

  Future<File> write({
    required File databaseFile,
    required File outputFile,
    required BPuzzlesManifest manifest,
    bool overwrite = false,
    void Function(int copiedBytes, int totalBytes)? onProgress,
  }) async {
    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'ObjectBox data.mdb nicht gefunden',
        databaseFile.path,
      );
    }

    final databaseLength = await databaseFile.length();
    if (databaseLength != manifest.database.sizeBytes) {
      throw ArgumentError(
        'Manifestgröße ${manifest.database.sizeBytes} stimmt nicht mit '
        'data.mdb ($databaseLength) überein',
      );
    }

    final actualHash = await sha256File(databaseFile);
    if (actualHash.toLowerCase() != manifest.database.sha256.toLowerCase()) {
      throw ArgumentError('Manifest-SHA-256 stimmt nicht mit data.mdb überein');
    }

    if (await outputFile.exists()) {
      if (!overwrite) {
        throw FileSystemException(
          'Ausgabedatei existiert bereits',
          outputFile.path,
        );
      }
      await outputFile.delete();
    }

    await outputFile.parent.create(recursive: true);
    final temporaryFile = File('${outputFile.path}.partial');
    if (await temporaryFile.exists()) {
      await temporaryFile.delete();
    }

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
    if (manifestBytes.length > _maxManifestBytes) {
      throw ArgumentError('Manifest ist zu groß');
    }

    final lengths = ByteData(12)
      ..setUint32(0, manifestBytes.length, Endian.little)
      ..setUint64(4, databaseLength, Endian.little);

    final sink = temporaryFile.openWrite();
    var copied = 0;

    try {
      try {
        sink.add(_magic);
        sink.add(lengths.buffer.asUint8List());
        sink.add(manifestBytes);

        await for (final chunk in databaseFile.openRead()) {
          sink.add(chunk);
          copied += chunk.length;
          onProgress?.call(copied, databaseLength);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } catch (_) {
      await _deleteIfExists(temporaryFile);
      rethrow;
    }

    if (copied != databaseLength) {
      await _deleteIfExists(temporaryFile);
      throw FileSystemException(
        'data.mdb wurde nicht vollständig verpackt',
        databaseFile.path,
      );
    }

    return temporaryFile.rename(outputFile.path);
  }
}

Future<List<int>> _readExactly(RandomAccessFile file, int length) async {
  final bytes = await file.read(length);
  if (bytes.length != length) {
    throw const FormatException('Unerwartetes Dateiende');
  }
  return bytes;
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

Future<void> _deleteIfExists(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } on FileSystemException {
    // Preserve the original package/import error.
  }
}
