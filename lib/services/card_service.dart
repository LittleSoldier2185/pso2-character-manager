import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/character_data.dart';
import '../models/tag_data.dart';

// Layout appended after PNG IEND: [MARKER(11 bytes)][JSON payload][LEN(4 bytes, big-endian)]
// Reading: last 4 bytes = len, then verify marker 11 bytes before the JSON.
const _kMarker = 'PSO2CM_CARD';
const int _kCardVersion = 1;

class CardPayload {
  final String name;
  final String race;
  final String gender;
  final int? tierIndex;
  final List<String> tagNames;
  final List<int> tagColors;
  final String description;
  final String originalFileName;
  final Uint8List fhpBytes;
  final Uint8List? thumbnailBytes;
  final String? thumbnailExt;

  const CardPayload({
    required this.name,
    required this.race,
    required this.gender,
    required this.tierIndex,
    required this.tagNames,
    required this.tagColors,
    required this.description,
    required this.originalFileName,
    required this.fhpBytes,
    required this.thumbnailBytes,
    required this.thumbnailExt,
  });

  CharacterTier? get tier => CharacterTier.fromInt(tierIndex);
}

class CardService {
  static final _markerBytes = Uint8List.fromList(utf8.encode(_kMarker));

  /// Writes [pngBytes] + embedded character payload to [savePath].
  /// [fhpPathOverride] / [thumbPathOverride] / [gameFileNameOverride] let
  /// variant exports supply the specific variant's files instead of the main ones.
  static Future<String?> saveCard({
    required Uint8List pngBytes,
    required CharacterData character,
    required List<TagData> resolvedTags,
    required String savePath,
    String? fhpPathOverride,
    String? thumbPathOverride,
    String? gameFileNameOverride,
    String? nameOverride,
  }) async {
    try {
      final fhpPath = fhpPathOverride ?? character.characterFilePath;
      if (fhpPath == null) return 'No character file found';
      final fhpBytes = await File(fhpPath).readAsBytes();

      String? thumbBase64;
      String? thumbExt;
      final thumbPath = thumbPathOverride ?? character.thumbnailPath;
      if (thumbPath != null && File(thumbPath).existsSync()) {
        thumbBase64 = base64Encode(await File(thumbPath).readAsBytes());
        thumbExt = thumbPath.split('.').last.toLowerCase();
      }

      final payload = utf8.encode(jsonEncode(<String, dynamic>{
        'v': _kCardVersion,
        'name': nameOverride ?? character.name,
        'race': character.race,
        'gender': character.gender,
        'tier': character.tierIndex,
        'tagNames': resolvedTags.map((t) => t.name).toList(),
        'tagColors': resolvedTags.map((t) => t.colorValue).toList(),
        'description': character.description,
        'originalFileName': gameFileNameOverride ?? character.gameFileName,
        'fhp': base64Encode(fhpBytes),
        'thumbnail': thumbBase64,
        'thumbnailExt': thumbExt,
      }));

      final lenBytes = ByteData(4)
        ..setUint32(0, payload.length, Endian.big);

      final out = Uint8List(
          pngBytes.length + _markerBytes.length + payload.length + 4);
      out.setAll(0, pngBytes);
      out.setAll(pngBytes.length, _markerBytes);
      out.setAll(pngBytes.length + _markerBytes.length, payload);
      out.setAll(pngBytes.length + _markerBytes.length + payload.length,
          lenBytes.buffer.asUint8List());

      await File(savePath).writeAsBytes(out);
      return null;
    } catch (e) {
      return 'Export failed: $e';
    }
  }

  /// Reads a card payload from a PNG file. Returns null if not a valid card.
  static Future<CardPayload?> readPayload(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      return _parse(bytes);
    } catch (_) {
      return null;
    }
  }

  static CardPayload? _parse(Uint8List bytes) {
    if (bytes.length < _markerBytes.length + 4 + 1) return null;

    // Read length from last 4 bytes
    final len = ByteData.sublistView(bytes, bytes.length - 4).getUint32(0, Endian.big);
    final jsonStart = bytes.length - 4 - len;
    final markerStart = jsonStart - _markerBytes.length;

    if (markerStart < 0 || jsonStart < 0 || len == 0) return null;

    // Verify marker
    for (int i = 0; i < _markerBytes.length; i++) {
      if (bytes[markerStart + i] != _markerBytes[i]) return null;
    }

    final json = jsonDecode(utf8.decode(bytes.sublist(jsonStart, jsonStart + len)))
        as Map<String, dynamic>;

    return CardPayload(
      name: json['name'] as String? ?? '',
      race: json['race'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      tierIndex: json['tier'] as int?,
      tagNames: (json['tagNames'] as List?)?.cast<String>() ?? [],
      tagColors: (json['tagColors'] as List?)?.cast<int>() ?? [],
      description: json['description'] as String? ?? '',
      originalFileName: json['originalFileName'] as String? ?? '',
      fhpBytes: base64Decode(json['fhp'] as String),
      thumbnailBytes: json['thumbnail'] != null
          ? base64Decode(json['thumbnail'] as String)
          : null,
      thumbnailExt: json['thumbnailExt'] as String?,
    );
  }

  static bool isPngFile(String path) =>
      path.toLowerCase().endsWith('.png');
}
